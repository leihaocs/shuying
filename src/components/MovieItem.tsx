import type { Movie } from '../types'
import { lastWatch, movieStatus } from '../lib/movies'
import { formatDate, relativeDay } from '../lib/utils'
import { Stars } from './Bits'

export default function MovieItem({
  movie,
  onClick,
}: {
  movie: Movie
  onClick: () => void
}) {
  const status = movieStatus(movie)
  const last = lastWatch(movie)

  return (
    <button className="item" onClick={onClick}>
      <div
        className="cover"
        style={{
          background: status === 'want' ? 'var(--surface-3)' : 'var(--info)',
        }}
      >
        <span>🎬</span>
      </div>
      <div className="item-main">
        <div className="item-title">{movie.title}</div>
        <div className="item-sub">
          导演 {movie.director}
          {movie.year ? ` · ${movie.year}` : ''}
        </div>

        <div className="item-meta">
          <span className={`pill ${status === 'want' ? 'want' : 'finished'}`}>
            {status === 'want' ? '想看' : `已看${movie.watches.length}次`}
          </span>
          {last ? (
            <>
              <span>{relativeDay(last.at)}看过</span>
              {last.rating ? (
                <>
                  <span className="dot-sep" />
                  <Stars value={last.rating} size={12} />
                </>
              ) : null}
            </>
          ) : (
            <>
              <span className="dot-sep" />
              <span>{formatDate(movie.createdAt)} 加入</span>
            </>
          )}
        </div>
      </div>
    </button>
  )
}
