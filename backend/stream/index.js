const express = require('express')
const Minio = require('minio')
const multer = require('multer')
const { v4: uuidv4 } = require('uuid')
const promClient = require('prom-client')
const k8s = require('@kubernetes/client-node')

const app = express()
app.use(express.json())

// ── Prometheus ────────────────────────────────────────────
promClient.collectDefaultMetrics({ prefix: 'ott_stream_' })
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType)
  res.send(await promClient.register.metrics())
})

// ── Kubernetes client ─────────────────────────────────────
const kc = new k8s.KubeConfig()
kc.loadFromCluster()
const batchV1Api = kc.makeApiClient(k8s.BatchV1Api)

// ── MinIO client (internal operations) ───────────────────
const minioClient = new Minio.Client({
  endPoint:  process.env.MINIO_HOST || 'minio',
  port:      parseInt(process.env.MINIO_PORT) || 9000,
  useSSL:    false,
  accessKey: process.env.MINIO_ROOT_USER || 'minioadmin',
  secretKey: process.env.MINIO_ROOT_PASSWORD || 'minioadmin123',
})

// ── MinIO client (external presigned URLs) ────────────────
const minioExternalClient = new Minio.Client({
  endPoint:  process.env.MINIO_EXTERNAL_HOST || '192.168.1.246',
  port:      parseInt(process.env.MINIO_EXTERNAL_PORT) || 9000,
  useSSL:    false,
  accessKey: process.env.MINIO_ROOT_USER || 'minioadmin',
  secretKey: process.env.MINIO_ROOT_PASSWORD || 'minioadmin123',
})

const RAW_BUCKET = 'raw-videos'
const HLS_BUCKET = 'hls-videos'

// ── Multer ────────────────────────────────────────────────
const upload = multer({ storage: multer.memoryStorage() })

// ── Create transcoding Job ────────────────────────────────
async function createTranscodeJob(videoId) {
  const jobManifest = {
    apiVersion: 'batch/v1',
    kind: 'Job',
    metadata: {
      name: `transcode-${videoId.substring(0, 8)}`,
      namespace: 'ott-media',
    },
    spec: {
      template: {
        metadata: {
          labels: { app: 'transcode-job' }
        },
        spec: {
          restartPolicy: 'Never',
          containers: [{
            name: 'ffmpeg',
            image: 'jrottenberg/ffmpeg:4.4-alpine',
            command: ['/bin/sh', '-c'],
            args: [`
              wget -q --no-check-certificate https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc || \
              wget -q https://github.com/minio/mc/releases/latest/download/mc.linux-amd64 -O /usr/local/bin/mc &&
              chmod +x /usr/local/bin/mc &&
              mc alias set minio http://$MINIO_HOST:$MINIO_PORT $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD &&
              mc cp minio/${RAW_BUCKET}/${videoId}/ /tmp/input/ --recursive &&
              INPUT=$(ls /tmp/input/*) &&
              mkdir -p /tmp/output/${videoId} &&
              ffmpeg -i "$INPUT" \
                -vf scale=1280:720 -c:v libx264 -b:v 2800k -c:a aac -b:a 128k \
                -f hls -hls_time 6 -hls_list_size 0 \
                -hls_segment_filename "/tmp/output/${videoId}/720p_%03d.ts" \
                /tmp/output/${videoId}/720p.m3u8 &&
              ffmpeg -i "$INPUT" \
                -vf scale=640:360 -c:v libx264 -b:v 800k -c:a aac -b:a 96k \
                -f hls -hls_time 6 -hls_list_size 0 \
                -hls_segment_filename "/tmp/output/${videoId}/360p_%03d.ts" \
                /tmp/output/${videoId}/360p.m3u8 &&
              cat > /tmp/output/${videoId}/master.m3u8 << EOF
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720
720p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
360p.m3u8
EOF
              mc cp /tmp/output/${videoId}/ minio/${HLS_BUCKET}/${videoId}/ --recursive
            `],
            env: [
              { name: 'MINIO_HOST', value: process.env.MINIO_HOST || 'minio.ott-media.svc.cluster.local' },
              { name: 'MINIO_PORT', value: process.env.MINIO_PORT || '9000' },
              { name: 'MINIO_ROOT_USER', value: process.env.MINIO_ROOT_USER || 'minioadmin' },
              { name: 'MINIO_ROOT_PASSWORD', value: process.env.MINIO_ROOT_PASSWORD || 'minioadmin123' },
            ]
          }]
        }
      }
    }
  }

  await batchV1Api.createNamespacedJob('ott-media', jobManifest)
  console.log(`Transcoding job created for videoId: ${videoId}`)
}

// ── Health check ──────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok', service: 'stream' }))

// ── Upload video ──────────────────────────────────────────
app.post('/stream/upload', upload.single('video'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' })

    const videoId  = uuidv4()
    const fileName = `${videoId}/${req.file.originalname}`

    await minioClient.putObject(
      RAW_BUCKET,
      fileName,
      req.file.buffer,
      req.file.size,
      { 'Content-Type': req.file.mimetype }
    )

    await createTranscodeJob(videoId)

    res.status(201).json({
      videoId,
      fileName,
      message: 'Video uploaded — transcoding job started',
      status: 'processing'
    })
  } catch (err) {
    console.error('Upload error:', err)
    res.status(500).json({ error: 'Upload failed' })
  }
})

// ── Get stream URL ────────────────────────────────────────
app.get('/stream/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params
    const manifestKey = `${videoId}/master.m3u8`

    await minioClient.statObject(HLS_BUCKET, manifestKey)

    // Use external client so presigned URL has external IP
    const url = await minioExternalClient.presignedGetObject(HLS_BUCKET, manifestKey, 3600)

    res.json({ videoId, manifestUrl: url, status: 'ready' })
  } catch (err) {
    if (err.code === 'NotFound') {
      return res.status(404).json({
        error: 'Stream not ready yet',
        status: 'processing'
      })
    }
    res.status(500).json({ error: 'Server error' })
  }
})

// ── List videos ───────────────────────────────────────────
app.get('/stream', async (req, res) => {
  try {
    const objects = []
    const stream  = minioClient.listObjects(RAW_BUCKET, '', true)
    stream.on('data', obj => objects.push(obj))
    stream.on('end', () => res.json(objects))
    stream.on('error', err => { throw err })
  } catch (err) {
    res.status(500).json({ error: 'Server error' })
  }
})

// ── Start ─────────────────────────────────────────────────
const PORT = process.env.PORT || 3003
app.listen(PORT, () => {
  console.log(`Stream service running on port ${PORT}`)
})