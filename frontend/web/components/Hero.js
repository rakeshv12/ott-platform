import Link from 'next/link'
import styles from './Hero.module.css'

export default function Hero({ featured }) {
  const item = featured || {
    id: 1,
    title: 'The Dark Meridian',
    description: 'A gripping tale of power, betrayal, and survival at the edge of civilization. One choice separates the hunter from the hunted.',
    genre: 'Thriller · Action',
    year: '2024',
    rating: 'HD',
    thumbnail: null,
  }

  return (
    <section className={styles.hero}>
      {/* Background */}
      <div className={styles.bg}>
        <img
          src={item.thumbnail || 'https://via.placeholder.com/1920x1080/0A0A0F/7C3AED?text='}
          alt=""
          aria-hidden="true"
        />
        <div className={styles.bgGradient} />
      </div>

      {/* Signature glow — light from behind the screen */}
      <div className={styles.glow} aria-hidden="true" />

      <div className={styles.content}>
        <div className={styles.eyebrow}>
          <span className={styles.badge}>Featured</span>
          <span className={styles.meta}>{item.year} · {item.genre}</span>
        </div>

        <h1 className={styles.title}>{item.title}</h1>
        <p className={styles.description}>{item.description}</p>

        <div className={styles.actions}>
          <Link href={`/watch/${item.id}`} className={styles.playBtn}>
            <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
              <path d="M8 5v14l11-7z"/>
            </svg>
            Play Now
          </Link>
          <Link href={`/title/${item.id}`} className={styles.infoBtn}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" width="20" height="20">
              <circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>
            </svg>
            More Info
          </Link>
        </div>

        <div className={styles.tags}>
          {['4K Ultra HD', 'Dolby Atmos', 'Subtitles'].map((tag) => (
            <span key={tag} className={styles.tag}>{tag}</span>
          ))}
        </div>
      </div>
    </section>
  )
}
