import Link from 'next/link'
import styles from './ContentCard.module.css'

export default function ContentCard({ item }) {
  return (
    <Link href={`/watch/${item.id}`} className={styles.card}>
      <div className={styles.thumb}>
        <img
          src={item.thumbnail || `https://via.placeholder.com/300x450/12121A/7C3AED?text=${encodeURIComponent(item.title)}`}
          alt={item.title}
          loading="lazy"
        />
        <div className={styles.overlay}>
          <button className={styles.playBtn} aria-label={`Play ${item.title}`}>
            <svg viewBox="0 0 24 24" fill="currentColor" width="28" height="28">
              <path d="M8 5v14l11-7z"/>
            </svg>
          </button>
          <div className={styles.meta}>
            {item.duration && <span>{item.duration}</span>}
            {item.rating && <span className={styles.rating}>{item.rating}</span>}
          </div>
        </div>
        {item.badge && <span className={styles.badge}>{item.badge}</span>}
      </div>
      <div className={styles.info}>
        <h3 className={styles.title}>{item.title}</h3>
        {item.genre && <p className={styles.genre}>{item.genre}</p>}
      </div>
    </Link>
  )
}
