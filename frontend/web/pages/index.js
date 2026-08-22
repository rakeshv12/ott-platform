import Head from 'next/head'
import Navbar from '../components/Navbar'
import Hero from '../components/Hero'
import ContentRow from '../components/ContentRow'
import styles from '../styles/Home.module.css'

export default function Home({ movies, series, trending }) {
  return (
    <>
      <Head>
        <title>StreamVault — Watch Anywhere</title>
        <meta name="description" content="Stream the latest movies and series in 4K Ultra HD." />
        <link rel="icon" href="/favicon.ico" />
      </Head>
      <Navbar />
      <Hero featured={trending[0]} />
      <main className={styles.main}>
        <ContentRow title="Trending Now" items={trending} />
        <ContentRow title="New Releases" items={movies} />
        <ContentRow title="Popular Series" items={series} />
      </main>
      <footer className={styles.footer}>
        <p className={styles.footerLogo}>STREAMVAULT</p>
        <p className={styles.footerCopy}>© 2024 StreamVault. All rights reserved.</p>
      </footer>
    </>
  )
}

export async function getServerSideProps() {
  const API = process.env.CATALOG_API || 'http://catalog-service.ott-backend.svc.cluster.local:3002'

  try {
    const [moviesRes, seriesRes, trendingRes] = await Promise.all([
      fetch(`${API}/catalog/movies`),
      fetch(`${API}/catalog/series`),
      fetch(`${API}/catalog/trending`),
    ])

    const movies   = await moviesRes.json()
    const series   = await seriesRes.json()
    const trending = await trendingRes.json()

    return { props: { movies, series, trending } }
  } catch (err) {
    console.error('Catalog API error:', err)
    return { props: { movies: [], series: [], trending: [] } }
  }
}