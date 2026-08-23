const express = require('express')
const Minio = require('minio')
const multer = require('multer')
const { v4: uuidv4 } = require('uuid')
const promClient = require('prom-client')

const app = express()
app.use(express.json())

// ── Prometheus ────────────────────────────────────────────
promClient.collectDefaultMetrics({ prefix: 'ott_stream_' })
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType)
  res.send(await promClient.register.metrics())
})

// ── MinIO client ──────────────────────────────────────────
const minioClient = new Minio.Client({
  endPoint:  process.env.MINIO_HOST || 'minio',
  port:      parseInt(process.env.MINIO_PORT) || 9000,
  useSSL:    false,
  accessKey: process.env.MINIO_ROOT_USER || 'minioadmin',
  secretKey: process.env.MINIO_ROOT_PASSWORD || 'minioadmin123',
})

const RAW_BUCKET = 'raw-videos'
const HLS_BUCKET = 'hls-videos'

// ── Multer — handle file uploads in memory ────────────────
const upload = multer({ storage: multer.memoryStorage() })

// ── Health check ──────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok', service: 'stream' }))

// ── Upload video ──────────────────────────────────────────
app.post('/stream/upload', upload.single('video'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' })

    const videoId   = uuidv4()
    const fileName  = `${videoId}/${req.file.originalname}`
    const metaData  = { 'Content-Type': req.file.mimetype }

    await minioClient.putObject(
      RAW_BUCKET,
      fileName,
      req.file.buffer,
      req.file.size,
      metaData
    )

    res.status(201).json({
      videoId,
      fileName,
      message: 'Video uploaded successfully — transcoding will begin shortly',
      status: 'uploaded'
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

    // Check if HLS manifest exists
    await minioClient.statObject(HLS_BUCKET, manifestKey)

    // Generate presigned URL valid for 1 hour
    const url = await minioClient.presignedGetObject(HLS_BUCKET, manifestKey, 3600)

    res.json({
      videoId,
      manifestUrl: url,
      status: 'ready'
    })
  } catch (err) {
    if (err.code === 'NotFound') {
      return res.status(404).json({
        error: 'Stream not ready yet — transcoding may still be in progress',
        status: 'processing'
      })
    }
    console.error('Stream error:', err)
    res.status(500).json({ error: 'Server error' })
  }
})

// ── List all videos ───────────────────────────────────────
app.get('/stream', async (req, res) => {
  try {
    const objects = []
    const stream  = minioClient.listObjects(RAW_BUCKET, '', true)

    stream.on('data', obj => objects.push(obj))
    stream.on('end', () => res.json(objects))
    stream.on('error', err => { throw err })
  } catch (err) {
    console.error('List error:', err)
    res.status(500).json({ error: 'Server error' })
  }
})

// ── Start ─────────────────────────────────────────────────
const PORT = process.env.PORT || 3003
app.listen(PORT, () => {
  console.log(`Stream service running on port ${PORT}`)
})