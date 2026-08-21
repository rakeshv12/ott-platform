Notes:
 kubectl get all -n ott-frontend
                  NAME                               READY   STATUS             RESTARTS   AGE
                  pod/frontend-web-774f4bfb5-fs7fh   0/1     ImagePullBackOff   0          4m9s
                  pod/frontend-web-774f4bfb5-kqt52   0/1     ImagePullBackOff   0          4m9s
kubectl events pod/frontend-web-774f4bfb5-fs7fh -n ott-frontend
LAST SEEN              TYPE      REASON              OBJECT                              MESSAGE
4m48s                  Normal    SuccessfulCreate    ReplicaSet/frontend-web-774f4bfb5   Created pod: frontend-web-774f4bfb5-fs7fh
4m48s                  Normal    ScalingReplicaSet   Deployment/frontend-web             Scaled up replica set frontend-web-774f4bfb5 from 0 to 2
4m48s                  Normal    IPAllocated         Service/frontend-web                Assigned IP ["192.168.1.243"]
4m48s                  Normal    Scheduled           Pod/frontend-web-774f4bfb5-kqt52    Successfully assigned ott-frontend/frontend-web-774f4bfb5-kqt52 to node2
4m48s                  Normal    Scheduled           Pod/frontend-web-774f4bfb5-fs7fh    Successfully assigned ott-frontend/frontend-web-774f4bfb5-fs7fh to node1
4m48s                  Normal    SuccessfulCreate    ReplicaSet/frontend-web-774f4bfb5   Created pod: frontend-web-774f4bfb5-kqt52
90s (x5 over 4m41s)    Normal    Pulling             Pod/frontend-web-774f4bfb5-fs7fh    Pulling image "rakeshv12/ott-frontend-web:latest"
85s (x5 over 4m31s)    Warning   Failed              Pod/frontend-web-774f4bfb5-fs7fh    Failed to pull image "rakeshv12/ott-frontend-web:latest": failed to pull and unpack image "docker.io/rakeshv12/ott-frontend-web:latest": failed to resolve reference "docker.io/rakeshv12/ott-frontend-web:latest": pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed
85s (x5 over 4m31s)    Warning   Failed              Pod/frontend-web-774f4bfb5-fs7fh    Error: ErrImagePull
76s (x5 over 4m23s)    Normal    Pulling             Pod/frontend-web-774f4bfb5-kqt52    Pulling image "rakeshv12/ott-frontend-web:latest"
72s (x5 over 4m19s)    Warning   Failed              Pod/frontend-web-774f4bfb5-kqt52    Failed to pull image "rakeshv12/ott-frontend-web:latest": failed to pull and unpack image "docker.io/rakeshv12/ott-frontend-web:latest": failed to resolve reference "docker.io/rakeshv12/ott-frontend-web:latest": pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed
72s (x5 over 4m19s)    Warning   Failed              Pod/frontend-web-774f4bfb5-kqt52    Error: ErrImagePull
22s (x15 over 4m19s)   Warning   Failed              Pod/frontend-web-774f4bfb5-kqt52    Error: ImagePullBackOff
22s (x15 over 4m30s)   Warning   Failed              Pod/frontend-web-774f4bfb5-fs7fh    Error: ImagePullBackOff
9s (x16 over 4m19s)    Normal    BackOff             Pod/frontend-web-774f4bfb5-kqt52    Back-off pulling image "rakeshv12/ott-frontend-web:latest"
8s (x16 over 4m30s)    Normal    BackOff             Pod/frontend-web-774f4bfb5-fs7fh    Back-off pulling image "rakeshv12/ott-frontend-web:latest"
root@Master:~/ott-platform#

