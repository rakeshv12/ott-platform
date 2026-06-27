import Head from 'next/head'
import Navbar from '../components/Navbar'
import Hero from '../components/Hero'
import ContentRow from '../components/ContentRow'
import styles from '../styles/Home.module.css'

// Mock data — replace with real API calls
const mockMovies = [
  { id: 1, title: 'Neon Abyss', genre: 'Sci-Fi', rating: '4K', duration: '2h 14m', badge: 'NEW' },
  { id: 2, title: 'Crimson Tide', genre: 'Thriller', rating: 'HD', duration: '1h 58m' },
  { id: 3, title: 'Stellar Drift', genre: 'Drama', rating: '4K', duration: '2h 02m' },
  { id: 4, title: 'Last Echo', genre: 'Action', rating: 'HD', duration: '1h 45m', badge: 'TOP 10' },
  { id: 5, title: 'The Hollow', genre: 'Horror', rating: '4K', duration: '1h 52m' },
  { id: 6, title: 'Aurora', genre: 'Romance', rating: 'HD', duration: '1h 38m' },
  { id: 7, title: 'Iron Protocol', genre: 'Action', rating: '4K', duration: '2h 20m' },
  { id: 8, title: 'Whisper Lake', genre: 'Mystery', rating: 'HD', duration: '1h 55m' },
]

const mockSeries = [
  { id: 9,  title: 'Dark Circuit', genre: 'Cyberpunk', rating: '4K', duration: 'S2 · 10 Ep', badge: 'NEW' },
  { id: 10, title: 'Syndicate', genre: 'Crime', rating: 'HD', duration: 'S1 · 8 Ep' },
  { id: 11, title: 'Frostline', genre: 'Thriller', rating: '4K', duration: 'S3 · 12 Ep' },
  { id: 12, title: 'The Agency', genre: 'Espionage', rating: 'HD', duration: 'S1 · 6 Ep', badge: 'TOP 10' },
  { id: 13, title: 'Veil City', genre: 'Drama', rating: '4K', duration: 'S2 · 8 Ep' },
  { id: 14, title: 'Parallel', genre: 'Sci-Fi', rating: 'HD', duration: 'S1 · 10 Ep' },
]

const mockTrending = [
  { id: 15, title: 'Zero Gravity', genre: 'Action', rating: '4K', duration: '2h 08m', badge: '#1' },
  { id: 16, title: 'Blood Stone', genre: 'Crime', rating: 'HD', duration: '1h 49m', badge: '#2' },
  { id: 17, title: 'Deep Current', genre: 'Thriller', rating: '4K', duration: '2h 01m', badge: '#3' },
  { id: 18, title: 'Phantom Grid', genre: 'Sci-Fi', rating: 'HD', duration: '1h 57m', badge: '#4' },
  { id: 19, title: 'Red Meridian', genre: 'Drama', rating: '4K', duration: '2h 15m', badge: '#5' },
  { id: 20, title: 'Night Shift', genre: 'Horror', rating: 'HD', duration: '1h 41m', badge: '#6' },
]

export default function Home() {
  return (
    <>
      <Head>
        <title>StreamVault — Watch Anywhere</title>
        <meta name="description" content="Stream the latest movies and series in 4K Ultra HD." />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <Navbar />
      <Hero />

      <main className={styles.main}>
        <ContentRow title="Trending Now" items={mockTrending} />
        <ContentRow title="New Releases" items={mockMovies} />
        <ContentRow title="Popular Series" items={mockSeries} />
        <ContentRow title="Continue Watching" items={mockMovies.slice(0, 5)} />
      </main>

      <footer className={styles.footer}>
        <p className={styles.footerLogo}>STREAMVAULT</p>
        <p className={styles.footerCopy}>© 2024 StreamVault. All rights reserved.</p>
      </footer>
    </>
  )
}
