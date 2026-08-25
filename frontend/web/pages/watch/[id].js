import { useEffect, useRef, useState } from 'react'
import Head from 'next/head'
import Link from 'next/link'
import styles from '../../styles/Watch.module.css'

export default function WatchPage({ manifestUrl, videoId, error }) {
  const videoRef = useRef(null)
  const playerRef = useRef(null)
  const [status, setStatus] = useState('loading')

  useEffect(() => {
    if (!manifestUrl || typeof window === 'undefined') return

    // Dynamically load Shaka Player
    const script = document.createElement('script')
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/shaka-player/4.7.6/shaka-player.compiled.js'
    script.onload = () => initPlayer()
    document.head.appendChild(script)

    return () => {
      if (playerRef.current) {
        playerRef.current.destroy()
      }
    }
  }, [manifestUrl])

  async function initPlayer() {
    if (!window.shaka || !videoRef.current) return

    // Install polyfills
    window.shaka.polyfill.installAll()

    if (!window.shaka.Player.isBrowserSupported()) {
      setStatus('unsupported')
      return
    }

    const player = new window.shaka.Player()
    await player.attach(videoRef.current)
    playerRef.current = player

    player.addEventListener('error', (event) => {
      console.error('Shaka error', event.detail)
      setStatus('error')
    })

    try {
      await player.load(manifestUrl)
      setStatus('playing')
      videoRef.current.play()
    } catch (err) {
      console.error('Load error', err)
      setStatus('error')
    }
  }

  return (
    <>
      <Head><title>Watch — StreamVault</title></Head>
      <div className={styles.page}>
        <div className={styles.topBar}>
          <Link href="/" className={styles.back}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" width="20" height="20">
              <path d="M19 12H5M12 5l-7 7 7 7"/>
            </svg>
            Back
          </Link>
          <span className={styles.logoSmall}>STREAMVAULT</span>
          <div />
        </div>

        <div className={styles.playerWrap}>
          <div className={styles.player}>
            {!manifestUrl && (
              <div className={styles.playerPlaceholder}>
                <div className={styles.playerGlow} aria-hidden="true" />
                <p className={styles.playerNote}>
                  {error || 'Stream not available yet'}
                </p>
                <p className={styles.playerSub}>
                  Upload a video to start streaming
                </p>
              </div>
            )}
            {manifestUrl && (
              <video
                ref={videoRef}
                className={styles.videoEl}
                controls
                autoPlay
                style={{ width: '100%', height: '100%', background: '#000' }}
              />
            )}
          </div>
        </div>

        <div className={styles.info}>
          <div className={styles.infoLeft}>
            <h1 className={styles.title}>Now Playing</h1>
            <div className={styles.meta}>
              {manifestUrl && <span className={styles.metaBadge}>LIVE</span>}
              <span>{status}</span>
            </div>
            <p className={styles.desc}>
              {manifestUrl
                ? 'Streaming via HLS adaptive bitrate — quality adjusts to your network speed automatically.'
                : 'No stream available for this content yet.'}
            </p>
          </div>
        </div>
      </div>
    </>
  )
}

export async function getServerSideProps({ params }) {
  const { id } = params
  const STREAM_API = process.env.STREAM_API || 'http://stream-service.ott-backend.svc.cluster.local:3003'

  try {
    const res = await fetch(`${STREAM_API}/stream/${id}`)
    const data = await res.json()

    if (data.status === 'ready') {
      return { props: { manifestUrl: data.manifestUrl, videoId: id, error: null } }
    }

    return { props: { manifestUrl: null, videoId: id, error: 'Stream not ready yet' } }
  } catch (err) {
    return { props: { manifestUrl: null, videoId: id, error: 'Stream service unavailable' } }
  }
}