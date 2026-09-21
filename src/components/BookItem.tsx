import type { Book } from '../types'
import {
  activeRound,
  bookStatus,
  bookSummary,
  roundProgress,
  statusLabel,
} from '../lib/books'
import { formatDuration, relativeDay } from '../lib/utils'

export default function BookItem({
  book,
  onClick,
}: {
  book: Book
  onClick: () => void
}) {
  const status = bookStatus(book)
  const round = activeRound(book)
  const sum = bookSummary(book)
  const pct = roundProgress(book, round)

  return (
    <button className="item" onClick={onClick}>
      <div className="cover" style={{ background: book.accent }}>
        <span>{book.cover}</span>
      </div>
      <div className="item-main">
        <div className="item-title">{book.title}</div>
        <div className="item-sub">{book.author}</div>

        {round && (
          <div className="bar" style={{ marginTop: 9 }}>
            <i style={{ width: `${pct}%` }} />
          </div>
        )}

        <div className="item-meta">
          <span className={`pill ${status}`}>{statusLabel(book)}</span>
          {round ? (
            <span>{pct}%</span>
          ) : sum.lastFinishedAt ? (
            <span>最近读完 {relativeDay(sum.lastFinishedAt)}</span>
          ) : null}
          {sum.totalMinutes > 0 && (
            <>
              <span className="dot-sep" />
              <span>{formatDuration(sum.totalMinutes)}</span>
            </>
          )}
        </div>
      </div>
    </button>
  )
}
