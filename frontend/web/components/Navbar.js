import { useState, useEffect } from 'react'
import Link from 'next/link'
import styles from './Navbar.module.css'

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 40)
    window.addEventListener('scroll', onScroll)
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <nav className={`${styles.nav} ${scrolled ? styles.scrolled : ''}`}>
      <Link href="/" className={styles.logo}>STREAMVAULT</Link>

      <ul className={`${styles.links} ${menuOpen ? styles.open : ''}`}>
        <li><Link href="/">Home</Link></li>
        <li><Link href="/browse">Browse</Link></li>
        <li><Link href="/browse?genre=movies">Movies</Link></li>
        <li><Link href="/browse?genre=series">Series</Link></li>
      </ul>

      <div className={styles.actions}>
        <button className={styles.searchBtn} aria-label="Search">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
          </svg>
        </button>
        <Link href="/login" className={styles.btnOutline}>Sign in</Link>
        <Link href="/register" className={styles.btnFill}>Start Free</Link>
        <button className={styles.burger} onClick={() => setMenuOpen(!menuOpen)} aria-label="Menu">
          <span/><span/><span/>
        </button>
      </div>
    </nav>
  )
}
