# Incident Runbook: Kubernetes API Server Unavailable — Expired Certificates

**Incident dates:** 2026-11-19 to 2026-11-20 (recovery on 2026-11-20 UTC)  
**Environment:** kubeadm Kubernetes v1.33.6, single control-plane host `master` (`172.16.254.132`), containerd, stacked local etcd v3.5.24  
**Status:** Control-plane recovery verified on 2026-11-20 UTC. The local etcd health probe committed a proposal, the API readiness check returned `ok`, and `master`, `node1`, and `node2` were `Ready`. Two workload errors were deferred.  
**Scope:** The incident record below preserves the available operator evidence. The reusable procedure includes additional checks and example commands. Where the record lacks literal command arguments or output, the result is described at the level supported by the evidence.

> **Security:** Never commit certificate private keys, `admin.conf`, etcd snapshots, or raw etcd data to Git. Store backups securely outside the repository.

## 1. Error details

```text
The connection to the server 172.16.254.132:6443 was refused
E1118 ... memcache.go:265 ... couldn't get current server API group list ...
Get "https://172.16.254.132:6443/api?timeout=32s":
dial tcp 172.16.254.132:6443: connect: connection refused
```

Kubelet was active, but could not register `master` with the API server. The API server container repeatedly exited (attempt 28 was observed). Its logs revealed:

```text
grpc ... 127.0.0.1:2379 ... authentication handshake failed:
tls: failed to verify certificate: x509: certificate has expired or is not yet valid:
current time 2026-11-19T05:02:54Z is after 2026-11-14T06:11:31Z
F1119 ... Error creating leases: error creating storage factory: context deadline exceeded
```

An etcd health check also failed with the same TLS-expiry message and `Error: unhealthy cluster`. This error **does not prove database corruption**.

## 2. Evidence and analysis

| Check | Observed result | Interpretation |
|---|---|---|
| `systemctl status kubelet` | active (running) | Node agent operating; unable to contact API |
| `systemctl status containerd` | active (running) | Container runtime operating |
| `crictl ps -a` | `kube-apiserver` Exited, attempt 28 | API process failing |
| `crictl ps` | etcd Running | Process running, not proof of etcd health |
| API server logs | TLS verification failure to `127.0.0.1:2379` | etcd TLS trust failure prevents API startup |
| `kubeadm certs check-expiration` | All 11 reported leaf certs expired 2026-11-14 06:11 UTC | Broad certificate expiry |
| Same command | ca, etcd-ca, front-proxy-ca valid until 2035 | CA replacement not indicated |
| etcd image | etcd v3.5.24, bundled etcdctl/etcdutl v3.5.24 | Prefer bundled clients over host etcdctl v3.2.26 |
| etcd manifest | hostPath `/var/lib/etcd`, endpoint `127.0.0.1:2379`, initial cluster `master=https://172.16.254.132:2380` | Local stacked etcd, apparently single-member; verify membership if needed |
| Online snapshot attempt | TLS failure; `etcd-before-renewal.db.part` was 0 bytes | **No valid snapshot confirmed** |
| Disk | `/var/lib/etcd` ~703 MB; root filesystem ~58 GB free | Space sufficient for backup |
| Kubernetes configuration archive | Requested file absent | **Configuration backup not confirmed** |

During the outage, the `kubeadm certs check-expiration` command could not read the `kubeadm-config` ConfigMap because the API server was down, and fell back to local/default configuration. For non-default layouts, verify the local configuration and certificate directory before relying on the inventory.

## 3. Root cause

**Confirmed:** kubeadm-managed leaf certificates expired on 2026-11-14. TLS validation between kube-apiserver and local etcd failed, so the API server could not initialize its storage layer and repeatedly exited. This explains connection refusals on TCP/6443 and downstream kubelet discovery/registration errors.

**Not established:** Why certificates were not renewed before expiry; whether clock synchronization contributed; whether every expired certificate independently caused a visible symptom; whether etcd data was damaged (no evidence of damage). The 256 KiB annotation error discussed in a separate incident is **unrelated** to this outage.

## 4. Incident chronology and operator evidence

### Investigation and failed online backup

The first API failure was at `172.16.254.132:6443`. Kubelet and containerd were active. The API server container (attempt 28) exited after TLS authentication to etcd on `127.0.0.1:2379` failed. The host etcdctl was v3.2.26, while the etcd container and its bundled etcdctl and etcdutl were v3.5.24. The manifest showed the stacked local data directory and peer endpoint `master=https://172.16.254.132:2380`. Disk checks found about 703 MB in the data directory and about 58 GB free on the root filesystem.

The online `etcdctl snapshot save` attempt failed on the expired TLS path. The recorded artifact was `/var/lib/etcd/etcd-before-renewal.db.part` (0 bytes). The etcd endpoint health probe returned the x509 expiry error and `Error: unhealthy cluster`. The intended Kubernetes configuration archive was absent and the operator chose to skip that archive. A PKI/configuration backup remains unverified.

While investigating why the static Pod did not stop promptly, the operator ran:

```bash
journalctl -u kubelet --since "30 minutes ago" --no-pager | grep -iE 'file.*source|static.*pod|remove.*pod|orphan|failed.*kill' | tail -30
```

Kubelet logged `Adding static pod path` for `/etc/kubernetes/manifests` at 19:55:37 PST on Nov 19 (03:55:37 UTC on Nov 20). Attempts to POST the node event to `https://172.16.254.132:6443/api/v1/namespaces/default/events` alternated among these failures:

```text
dial tcp 172.16.254.132:6443: connect: connection refused
net/http: TLS handshake timeout
read tcp 172.16.254.132:53792->172.16.254.132:6443: read: connection reset by peer
Unable to write event (retry limit exceeded!)
```

The event payload was `Reason:InvalidDiskCapacity`, `Message:invalid capacity 0 on image filesystem`, for `master`. This shows a kubelet event-delivery failure during the outage. The API server's etcd TLS log establishes the certificate root cause.

### Offline etcd copy and renewal

1. The operator moved the etcd manifest outside the watched directory. etcd container `dfca64a57d1e9` was still Running.
2. The operator ran `crictl stop dfca64a57d1e9`. The subsequent running-container check produced no etcd row.
3. The stopped data directory was copied to `/root/etcd-backup/etcd-data-before-renewal`. The copied `member/snap/db` showed 37 MB. This is the database file size, while the earlier 703 MB measurement covered the whole data directory.
4. `diff -qr /var/lib/etcd /root/etcd-backup/etcd-data-before-renewal` produced no output. The comparison confirmed no reported file-content differences. Restore testing and an off-node copy remain unverified.
5. The operator restored `/etc/kubernetes/manifests/etcd.yaml`. Kubelet recreated etcd as `b513e3b496765`, observed Running.
6. `kubeadm certs renew all` reported a ConfigMap read failure and used fallback configuration with the API unavailable. It completed renewal of all 11 leaf certificates and instructed the operator to restart the API server, controller-manager, scheduler, and etcd. Kubeadm renewal uses attributes from the existing certificates. The existing CAs remained valid.
7. `crictl stop b513e3b496765` returned `b513e3b496765`. etcd was recreated as `86dab6eedf145` and was Running. The bundled etcdctl `endpoint health` check returned:

   ```text
   https://127.0.0.1:2379 is healthy: successfully committed proposal: took = 435.577366ms
   ```

8. The recovery record also includes stopping the old scheduler with `crictl stop 219810a017f85`. The replacement API server was verified through the readiness and node checks below. The available record does not give exact API server and controller-manager restart commands or the shell command used to refresh the active kubeconfig.

### Post-renewal verification

| Check | Recorded result |
|---|---|
| API `/readyz` | `ok` |
| Node listing | `master`, `node1`, and `node2` all `Ready` |
| `kubectl get pods -A -o wide` | The API returned the cluster-wide inventory. Sample running Pods included Argo CD application and ApplicationSet controllers and an Argo Rollouts replica. Another Argo Rollouts Pod (suffix `lksvj`) had `CrashLoopBackOff`, and `minio-0` had `ImagePullBackOff`. The operator deferred those workload errors. |
| `kubeadm certs check-expiration` | All 11 leaf entries showed **Nov 20, 2027 at 04:20 UTC** (364 days remaining at the time of the check). All three CA entries showed **Nov 12, 2035** (8 years remaining). |

The 11 leaf entries were `admin.conf`, `apiserver`, `apiserver-etcd-client`, `apiserver-kubelet-client`, `controller-manager.conf`, `etcd-healthcheck-client`, `etcd-peer`, `etcd-server`, `front-proxy-client`, `scheduler.conf`, and `super-admin.conf`. The CA entries were `ca`, `etcd-ca`, and `front-proxy-ca`. The certificate inventory and readiness evidence establish control-plane recovery. End-to-end application validation remains open.

## 5. Diagnostic sequence and component flow

```text
kubectl -> TCP 172.16.254.132:6443 refused
  |
  +-> Verify IP / listener / kubeconfig: ip addr; ss -lntp; kubectl config view --minify
  |
  +-> Node services: systemctl status kubelet containerd
  |
  +-> Static pod manifests: ls /etc/kubernetes/manifests/
  |
  +-> CRI state: crictl ps -a
         |
         +-> kube-apiserver Exited -> crictl logs <ID>
         |      |
         |      +-> x509 TLS failure connecting to etcd :2379
         |
         +-> etcd Running -> verify endpoint and certificates
  |
  +-> Time and certificate inventory: date -u; timedatectl;
      kubeadm certs check-expiration; openssl x509 -noout -dates
  |
  +-> Secure backups -> renew -> controlled static pod restarts
  |
  +-> Verify etcd, /livez, /readyz, nodes, workloads, certificates
```

### Diagnostic commands for reuse (read-only)

```bash
hostname -f
ip -br addr
date -u
timedatectl status
sudo ss -lntp | grep -E ':6443|:2379'
sudo systemctl status kubelet containerd --no-pager
sudo journalctl -u kubelet -n 100 --no-pager
sudo ls -lah /etc/kubernetes/manifests/
sudo crictl ps -a | grep -E 'kube-apiserver|etcd|kube-scheduler|kube-controller-manager'
sudo crictl logs <FAILED_APISERVER_CONTAINER_ID> 2>&1 | tail -100
sudo kubeadm certs check-expiration
sudo openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -noout -subject -issuer -dates
sudo openssl x509 -in /etc/kubernetes/pki/apiserver-etcd-client.crt -noout -subject -issuer -dates
df -h / /var/lib/etcd
```

When API is down, `kubectl` cannot reliably diagnose the static pods. Use `crictl` and host logs instead.

## 6. Backup procedure for future renewals

**Observed:** Online `etcdctl snapshot save` did not produce a usable snapshot; `/var/lib/etcd/etcd-before-renewal.db.part` was zero bytes. Do not call this a successful backup. Avoid placing snapshots in the live etcd data directory.

### 6A. Preferred: verified online snapshot (only if TLS works)

Use matching etcdctl v3.5.24 (container binary) and valid TLS credentials. During this incident, expired certificates blocked the online snapshot before renewal. Do not disable TLS verification or use insecure endpoints as a workaround.

### 6B. Planned fallback: consistent offline data-directory copy

**Requires maintenance authorization.** For a single-member local etcd, stopping it makes the datastore unavailable. First verify the manifest mounts and that no other member or HA design changes the procedure. The following commands are a reusable procedure. The incident chronology records the commands and results that were recovered.

1. Keep a secure copy of Kubernetes configuration and PKI (recommended, although operator chose to skip the archive). At minimum, protect existing certificates, keys, manifests, and kubeconfigs. **Skipping configuration backup increases recovery risk.**
2. Ensure adequate disk space and create secure directories **outside** `/etc/kubernetes/manifests/`.
3. Copy the etcd static Pod manifest to a safe location; move the original out of the watched directory so kubelet stops etcd. Do **not** leave a duplicate manifest inside the watched directory.
4. Confirm the etcd process is no longer running before copying data.
5. Copy `/var/lib/etcd` with ownership, modes, and timestamps preserved.
6. Verify copied files and archive checksums; then restore the original manifest and confirm etcd container restarts.

```bash
# Preparation
sudo mkdir -p /root/etcd-backup/manifests
sudo chmod 700 /root/etcd-backup
sudo cp -p /etc/kubernetes/manifests/etcd.yaml /root/etcd-backup/manifests/etcd.yaml

# Stop the static pod by moving its manifest OUT of kubelet's watched directory.
sudo mv /etc/kubernetes/manifests/etcd.yaml /root/etcd-backup/manifests/etcd.yaml.stopped

# Wait for kubelet to stop etcd; DO NOT continue until BOTH checks confirm it stopped.
sudo crictl ps | grep etcd
pgrep -a etcd

# Only after etcd is fully stopped:
sudo cp -a /var/lib/etcd /root/etcd-backup/etcd-data-before-renewal
sudo du -sh /var/lib/etcd /root/etcd-backup/etcd-data-before-renewal
sudo diff -qr /var/lib/etcd /root/etcd-backup/etcd-data-before-renewal
sudo test -f /root/etcd-backup/etcd-data-before-renewal/member/snap/db && echo 'Database file present'
sudo test -d /root/etcd-backup/etcd-data-before-renewal/member/wal && echo 'WAL directory present'

# Restore manifest and let kubelet restart etcd:
sudo mv /root/etcd-backup/manifests/etcd.yaml.stopped /etc/kubernetes/manifests/etcd.yaml
sudo crictl ps | grep etcd
```

**Caution:** Validate the offline data-directory copy with a restore test in an isolated environment. A file comparison checks the copy; a restore test checks recoverability. Store a separate secure copy off the node where possible. If etcd does not stop, do not copy the live directory as a consistent backup.

## 7. Certificate renewal procedure

Confirm accurate system time, existing PKI/CA keys, backup status, and any custom kubeadm settings first. The CAs are valid; **do not regenerate or rotate CAs**.

```bash
sudo kubeadm certs check-expiration
# After prechecks/backups and operator approval:
sudo kubeadm certs renew all
sudo kubeadm certs check-expiration
```

Kubeadm renewal updates certificates on disk, but running components may retain old certificates. In this single-control-plane lab, restart affected static pods **one at a time**, by moving the manifest outside `/etc/kubernetes/manifests`, waiting for the old container to stop, and moving it back. Do not blindly restart all control-plane pods simultaneously. Handle etcd first if it needs to load new serving/peer certificates, then kube-apiserver, controller-manager, and scheduler. Use `crictl ps -a` and logs to confirm each restart.

For kubeconfig users with copied files, refresh their copies only after renewal:

```bash
# Only if root uses /root/.kube/config and it is intended to use kubeadm's admin.conf:
sudo install -d -m 700 /root/.kube
sudo cp /etc/kubernetes/admin.conf /root/.kube/config
sudo chmod 600 /root/.kube/config
```

Other users and automation may hold independent kubeconfig copies and must be evaluated separately.

## 8. Post-recovery verification procedure

```bash
sudo crictl ps | grep -E 'etcd|kube-apiserver|kube-scheduler|kube-controller-manager'
sudo ss -lntp | grep -E ':6443|:2379'
kubectl get --raw='/livez?verbose'
kubectl get --raw='/readyz?verbose'
kubectl get nodes -o wide
kubectl get pods -A
sudo kubeadm certs check-expiration
```

For etcd health after renewal, use the matching bundled etcdctl and valid credentials:

```bash
ETCD_ID=$(sudo crictl ps --name etcd -q | head -1)
sudo crictl exec "$ETCD_ID" etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  endpoint health
```

Validate DNS, CNI, application workloads, GitOps controllers, and external access after control-plane recovery.

## 9. Prevention and interview takeaway

- Schedule `kubeadm certs check-expiration` on each control-plane host and alert at 90, 60, and 30 days before the earliest expiry. Assign an owner and calendar the renewal before the warning thresholds are exhausted.
- Track distributed administrator kubeconfigs and check their embedded client-certificate expirations. Refresh the intended copies after renewal and verify a new authenticated session.
- Check whether planned kubeadm upgrades renew local certificates and record the resulting dates. Keep a supported manual renewal window if upgrade timing will not cover the certificate lifecycle. [Kubernetes kubeadm certificate management](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
- Keep time synchronization healthy; establish tested etcd snapshots and off-node backups.
- Record the certificate lifecycle in change management; restart static pods safely after renewal.
- For HA control planes, perform a separate member-by-member procedure with quorum checks; this single-member lab runbook is **not** an HA recovery recipe.
- Interview summary: `kubectl` failed because API port 6443 was unavailable. Kubelet/containerd were running, but `crictl` revealed a crashing API server. API logs showed expired TLS certificates on the etcd connection. Kubeadm confirmed expired leaf certificates and valid CAs. The safe remediation is backup, renewal, controlled restarts, and verification.

## 10. Incident follow-up checklist

- [x] Confirm API server connection refusal
- [x] Check kubelet/containerd
- [x] Inspect CRI control-plane containers and API logs
- [x] Confirm certificate expiry and CA validity
- [x] Inspect etcd version, hostPath, disk space
- [x] Establish online snapshot was unsuccessful
- [ ] Verify secure PKI/configuration backup or document accepted risk
- [x] Complete offline etcd copy and compare it with the stopped source
- [x] Renew kubeadm-managed leaf certificates and verify expiration dates
- [x] Verify recreated etcd, successful proposal, API readiness, and Ready nodes
- [x] Capture cluster-wide workload inventory and record deferred errors
- [ ] Confirm component-by-component restart evidence and active kubeconfig refresh details
- [ ] Verify an off-node backup and test restore
- [ ] Complete end-to-end application validation
- [ ] Add certificate expiry alerts and scheduled backup validation
