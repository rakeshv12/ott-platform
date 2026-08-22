const express = require('express')
const { Pool } = require('pg')
const redis = require('redis')
const promClient = require('prom-client')

const app = express()
app.use(express.json())

// ── Prometheus metrics ────────────────────────────────────
promClient.collectDefaultMetrics({ prefix: 'ott_catalog_' })

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType)
  res.send(await promClient.register.metrics())
})

// ── PostgreSQL ────────────────────────────────────────────
const pool = new Pool({
  host: process.env.POSTGRES_HOST || 'postgres',
  port: 5432,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.CATALOG_DB || 'catalogdb',
})

// ── Redis ─────────────────────────────────────────────────
const redisClient = redis.createClient({
  url: `redis://${process.env.REDIS_HOST || 'redis'}:6379`,
})
redisClient.connect().catch(console.error)

// ── DB init ───────────────────────────────────────────────
async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS content (
      id          SERIAL PRIMARY KEY,
      title       VARCHAR(255) NOT NULL,
      description TEXT,
      genre       VARCHAR(100),
      type        VARCHAR(50) DEFAULT 'movie',
      year        INTEGER,
      rating      VARCHAR(20),
      duration    VARCHAR(50),
      thumbnail   VARCHAR(500),
      badge       VARCHAR(50),
      trending    BOOLEAN DEFAULT false,
      created_at  TIMESTAMP DEFAULT NOW()
    );
  `)

  // Insert sample data if empty
  const count = await pool.query('SELECT COUNT(*) FROM content')
  if (parseInt(count.rows[0].count) === 0) {
    await pool.query(`
      INSERT INTO content (title, description, genre, type, year, rating, duration, badge, trending)
      VALUES
        ('The Dark Meridian', 'A gripping tale of power and betrayal', 'Thriller', 'movie', 2024, '4K', '2h 14m', 'NEW', true),
        ('Neon Abyss', 'A cyberpunk journey into the unknown', 'Sci-Fi', 'movie', 2024, 'HD', '1h 58m', null, true),
        ('Crimson Tide', 'Deep sea thriller', 'Thriller', 'movie', 2024, '4K', '2h 02m', null, false),
        ('Dark Circuit', 'Cyberpunk series', 'Cyberpunk', 'series', 2024, '4K', 'S2 · 10 Ep', 'NEW', true),
        ('Syndicate', 'Crime drama series', 'Crime', 'series', 2024, 'HD', 'S1 · 8 Ep', null, false),
        ('Zero Gravity', 'Space action thriller', 'Action', 'movie', 2024, '4K', '2h 08m', '#1', true),
        ('Blood Stone', 'Crime mystery', 'Crime', 'movie', 2024, 'HD', '1h 49m', '#2', true),
        ('Stellar Drift', 'Emotional space drama', 'Drama', 'movie', 2024, '4K', '2h 02m', null, false),
        ('Frostline', 'Arctic thriller series', 'Thriller', 'series', 2024, '4K', 'S3 · 12 Ep', null, false),
        ('Aurora', 'Romance in the northern lights', 'Romance', 'movie', 2024, 'HD', '1h 38m', null, false)
    `)
    console.log('Sample content inserted')
  }
  console.log('Catalog database initialised')
}

// ── Routes ────────────────────────────────────────────────

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', service: 'catalog' }))

// Get all movies
app.get('/catalog/movies', async (req, res) => {
  try {
    const cached = await redisClient.get('movies')
    if (cached) return res.json(JSON.parse(cached))

    const result = await pool.query(
      "SELECT * FROM content WHERE type = 'movie' ORDER BY created_at DESC"
    )
    await redisClient.setEx('movies', 300, JSON.stringify(result.rows))
    res.json(result.rows)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// Get all series
app.get('/catalog/series', async (req, res) => {
  try {
    const cached = await redisClient.get('series')
    if (cached) return res.json(JSON.parse(cached))

    const result = await pool.query(
      "SELECT * FROM content WHERE type = 'series' ORDER BY created_at DESC"
    )
    await redisClient.setEx('series', 300, JSON.stringify(result.rows))
    res.json(result.rows)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// Get trending
app.get('/catalog/trending', async (req, res) => {
  try {
    const cached = await redisClient.get('trending')
    if (cached) return res.json(JSON.parse(cached))

    const result = await pool.query(
      'SELECT * FROM content WHERE trending = true ORDER BY created_at DESC'
    )
    await redisClient.setEx('trending', 300, JSON.stringify(result.rows))
    res.json(result.rows)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// Get single title
app.get('/catalog/:id', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM content WHERE id = $1', [req.params.id]
    )
    if (!result.rows.length) return res.status(404).json({ error: 'Not found' })
    res.json(result.rows[0])
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// Search
app.get('/catalog/search', async (req, res) => {
  try {
    const { q } = req.query
    if (!q) return res.status(400).json({ error: 'Query required' })

    const result = await pool.query(
      'SELECT * FROM content WHERE title ILIKE $1 OR genre ILIKE $1',
      [`%${q}%`]
    )
    res.json(result.rows)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Server error' })
  }
})

// ── Start ─────────────────────────────────────────────────
const PORT = process.env.PORT || 3002
app.listen(PORT, async () => {
  await initDB()
  console.log(`Catalog service running on port ${PORT}`)
})