import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useStore } from '../store'
import {
  activeRound,
  bookStatus,
  bookSummary,
  finishedRounds,
  roundMinutes,
  roundPages,
  roundProgress,
  sortedLogs,
  statusLabel,
} from '../lib/books'
import {
  formatDate,
  formatDateTime,
  formatDuration,
  relativeDay,
} from '../lib/utils'
import ProgressRing from '../components/ProgressRing'
import BookForm from '../components/forms/BookForm'
import LogForm from '../components/forms/LogForm'
import PastRoundForm from '../components/forms/PastRoundForm'
import { Confirm, EmptyState, useToast } from '../components/Bits'

export default function BookDetailPage() {
  const { id = '' } = useParams()
  const navigate = useNavigate()
  const store = useStore()
  const book = store.books.find((b) => b.id === id)

  const [logOpen, setLogOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [pastOpen, setPastOpen] = useState(false)
  const [delOpen, setDelOpen] = useState(false)
  const [delRoundId, setDelRoundId] = useState<string | null>(null)
  const { toast, show } = useToast()

  if (!book) {
    return (
      <div className="page no-tabs">
        <div className="navbar">
          <button className="icon-btn" onClick={() => navigate('/')} aria-label="返回">
            ←
          </button>
        </div>
        <EmptyState icon="🔍" title="这本书不见了" desc="它可能已经被删除" />
      </div>
    )
  }

  const status = bookStatus(book)
  const round = activeRound(book)
  const sum = bookSummary(book)
  const past = finishedRounds(book)
  const pct = roundProgress(book, round)

  const finish = () => {
    if (!round) return
    store.finishRound(book.id, round.id)
    show(`已记录第 ${round.index} 次读完`)
  }

  return (
    <div className="page no-tabs">
      <div className="navbar">
        <button className="icon-btn" onClick={() => navigate(-1)} aria-label="返回">
          ←
        </button>
        <div className="navbar-title">{book.title}</div>
        <button className="icon-btn" onClick={() => setEditOpen(true)} aria-label="编辑">
          ✎
        </button>
      </div>

      <div className="hero">
        <div className="hero-cover" style={{ background: book.accent }}>
          <span>{book.cover}</span>
        </div>
        <div className="hero-info">
          <h1 className="hero-title">{book.title}</h1>
          <div className="hero-author">{book.author}</div>
          <div className="hero-tags">
            <span className={`pill ${status}`}>{statusLabel(book)}</span>
            {book.totalPages ? (
              <span className="pill plain">{book.totalPages} 页</span>
            ) : null}
          </div>
        </div>
      </div>

      {round ? (
        <div className="section">
          <div className="progress-card">
            <ProgressRing value={pct} />
            <div className="progress-side">
              <span className="pill reading">第 {round.index} 次阅读 · 进行中</span>
              <div style={{ marginTop: 9, fontSize: 14, fontWeight: 600 }}>
                已读 {roundPages(round)} 页
                <span style={{ color: 'var(--text-3)', fontWeight: 400 }}>
                  {' '}
                  · {formatDuration(roundMinutes(round))}
                </span>
              </div>
              <div style={{ marginTop: 2, fontSize: 12.5, color: 'var(--text-3)' }}>
                {relativeDay(round.startedAt)}开始 · 已记录 {round.logs.length} 次
              </div>
            </div>
          </div>

          <div className="btn-row" style={{ marginTop: 12 }}>
            <button className="btn primary" onClick={() => setLogOpen(true)}>
              记录本次
            </button>
            <button className="btn ghost" onClick={finish}>
              标记读完
            </button>
          </div>
        </div>
      ) : status === 'want' ? (
        <div className="section">
          <div className="btn-row">
            <button className="btn primary" onClick={() => store.startReading(book.id)}>
              开始阅读
            </button>
            <button className="btn ghost" onClick={() => setPastOpen(true)}>
              补记往期
            </button>
          </div>
        </div>
      ) : (
        <div className="section">
          <div className="btn-row">
            <button className="btn primary" onClick={() => store.startReading(book.id)}>
              再读一次
            </button>
            <button className="btn ghost" onClick={() => setPastOpen(true)}>
              补记往期
            </button>
          </div>
        </div>
      )}

      <div className="section">
        <div className="section-title">阅读总计</div>
        <div className="stat-grid">
          <div className="stat">
            <div className="stat-value">{sum.totalPages}</div>
            <div className="stat-label">累计页数</div>
          </div>
          <div className="stat">
            <div className="stat-value">
              {sum.totalMinutes >= 60
                ? `${Math.round((sum.totalMinutes / 60) * 10) / 10}h`
                : `${sum.totalMinutes}m`}
            </div>
            <div className="stat-label">累计时长</div>
          </div>
          <div className="stat">
            <div className="stat-value">{sum.readTimes}</div>
            <div className="stat-label">读完次数</div>
          </div>
        </div>
      </div>

      {round && (
        <div className="section">
          <div className="section-title">
            <span>本次阅读记录</span>
            <span>{round.logs.length} 条</span>
          </div>
          {round.logs.length === 0 ? (
            <div className="card" style={{ padding: 16, color: 'var(--text-3)', fontSize: 13.5 }}>
              还没有记录，点上面的「记录本次」写下这次读了多少页或多久。
            </div>
          ) : (
            <div className="timeline">
              {sortedLogs(round).map((log) => (
                <div className="tl-item" key={log.id}>
                  <div className="tl-body">
                    <div className="tl-head">
                      <span className="tl-date">{relativeDay(log.at)}</span>
                      <span style={{ fontSize: 12, color: 'var(--text-3)' }}>
                        {formatDateTime(log.at)}
                      </span>
                    </div>
                    <div className="tl-how">
                      {log.pages ? <span>📄 {log.pages} 页</span> : null}
                      {log.minutes ? <span>⏱ {formatDuration(log.minutes)}</span> : null}
                      {typeof log.progress === 'number' ? (
                        <span>📈 进度 {log.progress}%</span>
                      ) : null}
                    </div>
                    {log.note && <div className="tl-note">{log.note}</div>}
                  </div>
                  <button
                    className="tl-del"
                    onClick={() => store.removeLog(book.id, log.id)}
                    aria-label="删除这条记录"
                  >
                    ✕
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      <div className="section">
        <div className="section-title">
          <span>往期阅读（已读完）</span>
          <span>{past.length} 次</span>
        </div>
        {past.length === 0 ? (
          <div className="card" style={{ padding: 16, color: 'var(--text-3)', fontSize: 13.5 }}>
            还没有读完过。经典值得读很多遍，读完第一次后可以继续「再读一次」。
          </div>
        ) : (
          <div className="list">
            {past.map((r) => (
              <div className="round" key={r.id}>
                <div className="round-index">{r.index}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 600 }}>
                    {formatDate(r.startedAt)} → {formatDate(r.finishedAt)}
                  </div>
                  <div className="item-meta" style={{ paddingTop: 4 }}>
                    <span>{formatDuration(roundMinutes(r))}</span>
                    <span className="dot-sep" />
                    <span>{roundPages(r)} 页</span>
                    {r.logs.length > 0 ? (
                      <>
                        <span className="dot-sep" />
                        <span>{r.logs.length} 条记录</span>
                      </>
                    ) : null}
                  </div>
                  {r.logs[0]?.note && <div className="tl-note">{r.logs[0].note}</div>}
                </div>
                <button
                  className="icon-btn small"
                  onClick={() => setDelRoundId(r.id)}
                  aria-label="删除这次阅读"
                >
                  ✕
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="section">
        <div className="section-title">书籍信息</div>
        <div className="card" style={{ padding: '2px 14px' }}>
          <div className="info-row">
            <span className="info-key">作者</span>
            <span className="info-val">{book.author}</span>
          </div>
          <div className="info-row">
            <span className="info-key">总页数</span>
            <span className="info-val">{book.totalPages ?? '未填写'}</span>
          </div>
          <div className="info-row">
            <span className="info-key">加入时间</span>
            <span className="info-val">{formatDate(book.createdAt)}</span>
          </div>
          <div className="info-row">
            <span className="info-key">最近阅读</span>
            <span className="info-val">
              {sum.lastLogAt ? relativeDay(sum.lastLogAt) : '还没有'}
            </span>
          </div>
          {book.note && (
            <div className="info-row">
              <span className="info-key">备注</span>
              <span className="info-val note-box">{book.note}</span>
            </div>
          )}
        </div>

        <button
          className="btn danger block"
          style={{ marginTop: 14 }}
          onClick={() => setDelOpen(true)}
        >
          删除这本书
        </button>
      </div>

      <BookForm
        open={editOpen}
        onClose={() => setEditOpen(false)}
        initial={book}
        onSubmit={(input) => {
          store.updateBook(book.id, input)
          show('已保存')
        }}
      />

      {round && (
        <LogForm
          open={logOpen}
          onClose={() => setLogOpen(false)}
          book={book}
          round={round}
          onSubmit={(log, alsoFinish) => {
            store.addLog(book.id, round.id, log)
            if (alsoFinish) store.finishRound(book.id, round.id)
            show(alsoFinish ? `已读完第 ${round.index} 次` : '已记录本次阅读')
          }}
        />
      )}

      <PastRoundForm
        open={pastOpen}
        onClose={() => setPastOpen(false)}
        bookTitle={book.title}
        onSubmit={(input) => {
          store.addPastRound(book.id, input)
          show('已补记一次阅读')
        }}
      />

      <Confirm
        open={delOpen}
        title="删除这本书？"
        desc="所有阅读记录都会一起删除，且无法恢复"
        onCancel={() => setDelOpen(false)}
        onConfirm={() => {
          store.removeBook(book.id)
          navigate('/', { replace: true })
        }}
      />

      <Confirm
        open={delRoundId !== null}
        title="删除这一次阅读？"
        desc="这一轮的全部记录会一起删除"
        onCancel={() => setDelRoundId(null)}
        onConfirm={() => {
          if (delRoundId) store.removeRound(book.id, delRoundId)
          show('已删除')
        }}
      />

      {toast}
    </div>
  )
}
