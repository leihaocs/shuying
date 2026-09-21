import { useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../store'
import { bookSummary, roundProgress, activeRound } from '../lib/books'
import { sortedWatches } from '../lib/movies'
import { formatDuration, relativeDay } from '../lib/utils'
import { useToast } from '../components/Bits'

const WEEK = ['日', '一', '二', '三', '四', '五', '六']

export default function StatsPage() {
  const navigate = useNavigate()
  const { books, movies, theme, toggleTheme } = useStore()
  const { toast } = useToast()

  const data = useMemo(() => {
    const logs = books.flatMap((b) =>
      b.rounds.flatMap((r) =>
        r.logs.map((l) => ({ ...l, bookId: b.id, bookTitle: b.title, cover: b.cover })),
      ),
    )
    const watches = movies.flatMap((m) =>
      sortedWatches(m).map((w) => ({
        ...w,
        movieId: m.id,
        movieTitle: m.title,
      })),
    )

    const minutes = logs.reduce((s, l) => s + (l.minutes || 0), 0)
    const pages = logs.reduce((s, l) => s + (l.pages || 0), 0)
    const readTimes = books.reduce((s, b) => s + bookSummary(b).readTimes, 0)
    const watchTimes = movies.reduce((s, m) => s + m.watches.length, 0)

    // 近 7 日阅读时长
    const today = new Date()
    const days = Array.from({ length: 7 }, (_, i) => {
      const d = new Date(today)
      d.setDate(today.getDate() - (6 - i))
      const key = `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`
      const mins = logs
        .filter((l) => {
          const x = new Date(l.at)
          return `${x.getFullYear()}-${x.getMonth() + 1}-${x.getDate()}` === key
        })
        .reduce((s, l) => s + (l.minutes || 0), 0)
      return { label: WEEK[d.getDay()], day: `${d.getMonth() + 1}/${d.getDate()}`, mins, isToday: i === 6 }
    })

    const activity = [
      ...logs.map((l) => ({
        kind: 'read' as const,
        at: l.at,
        title: l.bookTitle,
        id: l.id,
        bookId: l.bookId,
        detail: [
          l.pages ? `${l.pages} 页` : '',
          l.minutes ? formatDuration(l.minutes) : '',
          typeof l.progress === 'number' ? `进度 ${l.progress}%` : '',
        ]
          .filter(Boolean)
          .join(' · '),
      })),
      ...watches.map((w) => ({
        kind: 'watch' as const,
        at: w.at,
        title: w.movieTitle,
        id: w.id,
        movieId: w.movieId,
        detail: w.rating ? `${w.rating} 星` : '看过',
      })),
    ]
      .sort((a, b) => b.at.localeCompare(a.at))
      .slice(0, 8)

    const reading = books.filter((b) => activeRound(b))

    return {
      minutes,
      pages,
      readTimes,
      watchTimes,
      days,
      activity,
      reading,
      maxMins: Math.max(...days.map((d) => d.mins), 1),
    }
  }, [books, movies])

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <h1 className="page-title">统计</h1>
          <p className="page-sub">点点滴滴，都在这里</p>
        </div>
        <button className="icon-btn" onClick={toggleTheme} aria-label="切换主题">
          {theme === 'dark' ? '☀️' : '🌙'}
        </button>
      </div>

      <div className="section" style={{ marginTop: 4 }}>
        <div className="stat-grid">
          <div className="stat">
            <div className="stat-value">{data.readTimes}</div>
            <div className="stat-label">读完次数</div>
          </div>
          <div className="stat">
            <div className="stat-value">
              {data.minutes >= 60 ? `${Math.round(data.minutes / 60)}h` : `${data.minutes}m`}
            </div>
            <div className="stat-label">阅读时长</div>
          </div>
          <div className="stat">
            <div className="stat-value">{data.pages}</div>
            <div className="stat-label">累计页数</div>
          </div>
        </div>
        <div className="stat-grid" style={{ marginTop: 10 }}>
          <div className="stat">
            <div className="stat-value">{books.length}</div>
            <div className="stat-label">书架书籍</div>
          </div>
          <div className="stat">
            <div className="stat-value">{movies.length}</div>
            <div className="stat-label">电影收藏</div>
          </div>
          <div className="stat">
            <div className="stat-value">{data.watchTimes}</div>
            <div className="stat-label">观影次数</div>
          </div>
        </div>
      </div>

      <div className="section">
        <div className="section-title">近 7 天阅读时长</div>
        <div className="card">
          <div className="chart">
            {data.days.map((d, i) => (
              <div
                className={`chart-col${d.isToday ? ' today' : ''}`}
                key={i}
                title={`${d.day} · ${d.mins} 分钟`}
              >
                <div
                  className="chart-bar"
                  style={{
                    height: `${Math.max((d.mins / data.maxMins) * 100, d.mins > 0 ? 8 : 2)}%`,
                    opacity: d.mins > 0 ? 1 : 0.25,
                  }}
                />
                <span className="chart-label">{d.label}</span>
              </div>
            ))}
          </div>
          <div
            style={{
              padding: '4px 14px 13px',
              fontSize: 12.5,
              color: 'var(--text-3)',
              textAlign: 'center',
            }}
          >
            本周共 {formatDuration(data.days.reduce((s, d) => s + d.mins, 0))}
          </div>
        </div>
      </div>

      {data.reading.length > 0 && (
        <div className="section">
          <div className="section-title">正在读</div>
          <div className="list">
            {data.reading.map((b) => {
              const r = activeRound(b)
              const pct = roundProgress(b, r)
              return (
                <button
                  key={b.id}
                  className="item"
                  onClick={() => navigate(`/books/${b.id}`)}
                >
                  <div className="cover sm" style={{ background: b.accent }}>
                    <span>{b.cover}</span>
                  </div>
                  <div className="item-main">
                    <div className="item-title" style={{ fontSize: 14.5 }}>
                      {b.title}
                    </div>
                    <div className="bar" style={{ marginTop: 7 }}>
                      <i style={{ width: `${pct}%` }} />
                    </div>
                    <div className="item-meta">
                      <span>{b.author}</span>
                      <span className="dot-sep" />
                      <span>{pct}%</span>
                    </div>
                  </div>
                </button>
              )
            })}
          </div>
        </div>
      )}

      <div className="section">
        <div className="section-title">最近动态</div>
        {data.activity.length === 0 ? (
          <div className="card" style={{ padding: 16, color: 'var(--text-3)', fontSize: 13.5 }}>
            还没有任何记录，去书架添加一本书开始吧。
          </div>
        ) : (
          <div className="timeline">
            {data.activity.map((a) => (
              <div className="tl-item" key={`${a.kind}-${a.id}`}>
                <div
                  className="tl-body"
                  onClick={() =>
                    navigate(
                      a.kind === 'read' ? `/books/${a.bookId}` : `/movies/${a.movieId}`,
                    )
                  }
                  style={{ cursor: 'pointer' }}
                >
                  <div className="tl-head">
                    <span className="tl-date">
                      {a.kind === 'read' ? '📖' : '🎬'} {a.title}
                    </span>
                    <span style={{ fontSize: 12, color: 'var(--text-3)' }}>
                      {relativeDay(a.at)}
                    </span>
                  </div>
                  <div className="tl-how">{a.detail}</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div
        style={{
          marginTop: 34,
          textAlign: 'center',
          fontSize: 12,
          color: 'var(--text-3)',
        }}
      >
        数据保存在本机浏览器中
      </div>

      {toast}
    </div>
  )
}
