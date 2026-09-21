import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useStore } from '../store'
import { movieStatus, sortedWatches } from '../lib/movies'
import { formatDate, formatDateTime, relativeDay } from '../lib/utils'
import MovieForm from '../components/forms/MovieForm'
import WatchForm from '../components/forms/WatchForm'
import { Confirm, EmptyState, Stars, useToast } from '../components/Bits'

export default function MovieDetailPage() {
  const { id = '' } = useParams()
  const navigate = useNavigate()
  const store = useStore()
  const movie = store.movies.find((m) => m.id === id)

  const [editOpen, setEditOpen] = useState(false)
  const [watchOpen, setWatchOpen] = useState(false)
  const [delOpen, setDelOpen] = useState(false)
  const [delWatchId, setDelWatchId] = useState<string | null>(null)
  const { toast, show } = useToast()

  if (!movie) {
    return (
      <div className="page no-tabs">
        <div className="navbar">
          <button className="icon-btn" onClick={() => navigate('/movies')} aria-label="返回">
            ←
          </button>
        </div>
        <EmptyState icon="🔍" title="这部片子不见了" desc="它可能已经被删除" />
      </div>
    )
  }

  const status = movieStatus(movie)
  const watches = sortedWatches(movie)
  const rated = watches.filter((w) => w.rating)
  const avgRating = rated.length
    ? Math.round(
        (rated.reduce((s, w) => s + (w.rating || 0), 0) / rated.length) * 10,
      ) / 10
    : 0

  return (
    <div className="page no-tabs">
      <div className="navbar">
        <button className="icon-btn" onClick={() => navigate(-1)} aria-label="返回">
          ←
        </button>
        <div className="navbar-title">{movie.title}</div>
        <button className="icon-btn" onClick={() => setEditOpen(true)} aria-label="编辑">
          ✎
        </button>
      </div>

      <div className="hero">
        <div
          className="hero-cover"
          style={{
            background: status === 'want' ? 'var(--surface-3)' : 'var(--info)',
          }}
        >
          <span>🎬</span>
        </div>
        <div className="hero-info">
          <h1 className="hero-title">{movie.title}</h1>
          <div className="hero-author">
            导演 {movie.director}
            {movie.year ? ` · ${movie.year}` : ''}
          </div>
          <div className="hero-tags">
            <span className={`pill ${status === 'want' ? 'want' : 'finished'}`}>
              {status === 'want' ? '想看' : `已看${movie.watches.length}次`}
            </span>
            {avgRating > 0 ? (
              <span className="pill plain">平均 {avgRating} 星</span>
            ) : null}
          </div>
        </div>
      </div>

      <div className="section">
        <div className="btn-row">
          <button className="btn primary" onClick={() => setWatchOpen(true)}>
            {status === 'want' ? '标记为已看' : '再看一次'}
          </button>
        </div>
      </div>

      <div className="section">
        <div className="section-title">
          <span>观影记录</span>
          <span>{watches.length} 次</span>
        </div>
        {watches.length === 0 ? (
          <div className="card" style={{ padding: 16, color: 'var(--text-3)', fontSize: 13.5 }}>
            还没有看过。看完了就点上面的「标记为已看」，以前看过的也可以补记时间。
          </div>
        ) : (
          <div className="timeline">
            {watches.map((w) => (
              <div className="tl-item done" key={w.id}>
                <div className="tl-body">
                  <div className="tl-head">
                    <span className="tl-date">{relativeDay(w.at)}</span>
                    <span style={{ fontSize: 12, color: 'var(--text-3)' }}>
                      {formatDateTime(w.at)}
                    </span>
                  </div>
                  {w.rating ? (
                    <div style={{ marginTop: 4 }}>
                      <Stars value={w.rating} size={15} />
                    </div>
                  ) : null}
                  {w.note && <div className="tl-note">{w.note}</div>}
                </div>
                <button
                  className="tl-del"
                  onClick={() => setDelWatchId(w.id)}
                  aria-label="删除这次记录"
                >
                  ✕
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="section">
        <div className="section-title">电影信息</div>
        <div className="card" style={{ padding: '2px 14px' }}>
          <div className="info-row">
            <span className="info-key">导演</span>
            <span className="info-val">{movie.director}</span>
          </div>
          <div className="info-row">
            <span className="info-key">上映年份</span>
            <span className="info-val">{movie.year ?? '未填写'}</span>
          </div>
          <div className="info-row">
            <span className="info-key">加入时间</span>
            <span className="info-val">{formatDate(movie.createdAt)}</span>
          </div>
          <div className="info-row">
            <span className="info-key">最近观看</span>
            <span className="info-val">
              {watches[0] ? relativeDay(watches[0].at) : '还没有'}
            </span>
          </div>
          {movie.note && (
            <div className="info-row">
              <span className="info-key">备注</span>
              <span className="info-val note-box">{movie.note}</span>
            </div>
          )}
        </div>

        <button
          className="btn danger block"
          style={{ marginTop: 14 }}
          onClick={() => setDelOpen(true)}
        >
          删除这部电影
        </button>
      </div>

      <MovieForm
        open={editOpen}
        onClose={() => setEditOpen(false)}
        initial={movie}
        onSubmit={(input) => {
          store.updateMovie(movie.id, input)
          show('已保存')
        }}
      />

      <WatchForm
        open={watchOpen}
        onClose={() => setWatchOpen(false)}
        title={status === 'want' ? '标记为已看' : '再看一次'}
        subtitle={`《${movie.title}》`}
        onSubmit={(watch) => {
          store.addWatch(movie.id, watch)
          show(`已是第 ${movie.watches.length + 1} 次观看`)
        }}
      />

      <Confirm
        open={delOpen}
        title="删除这部电影？"
        desc="所有观影记录都会一起删除，且无法恢复"
        onCancel={() => setDelOpen(false)}
        onConfirm={() => {
          store.removeMovie(movie.id)
          navigate('/movies', { replace: true })
        }}
      />

      <Confirm
        open={delWatchId !== null}
        title="删除这次观影记录？"
        onCancel={() => setDelWatchId(null)}
        onConfirm={() => {
          if (delWatchId) store.removeWatch(movie.id, delWatchId)
          show('已删除')
        }}
      />

      {toast}
    </div>
  )
}
