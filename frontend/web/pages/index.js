import Head from 'next/head'
import { useEffect, useState } from 'react'
import Navbar from '../components/Navbar'
import Hero from '../components/Hero'
import ContentRow from '../components/ContentRow'
import styles from '../styles/Home.module.css'

export default function Home() {
  const [movies, setMovies] = useState([])
  const [series, setSeries] = useState([])
  const [trending, setTrending] = useState([])

  useEffect(() => {
    const API = process.env.NEXT_PUBLIC_CATALOG_API

    fetch(`${API}/catalog/movies`)
      .then(r => r.json())
      .then(setMovies)
      .catch(console.error)

    fetch(`${API}/catalog/series`)
      .then(r => r.json())
      .then(setSeries)
      .catch(console.error)

    fetch(`${API}/catalog/trending`)
      .then(r => r.json())
      .then(setTrending)
      .catch(console.error)
  }, [])

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