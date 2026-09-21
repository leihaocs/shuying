import { useEffect, useState } from 'react'
import Sheet from '../Sheet'
import type { Book, ReadingRound } from '../../types'
import type { LogInput } from '../../store'
import { roundProgress } from '../../lib/books'
import { clamp, fromInput, parseNum, toDateTimeInput } from '../../lib/utils'
import { DurationField, toMinutes } from './shared'

interface Props {
  open: boolean
  onClose: () => void
  book: Book
  round: ReadingRound
  onSubmit: (log: LogInput, alsoFinish: boolean) => void
}

export default function LogForm({
  open,
  onClose,
  book,
  round,
  onSubmit,
}: Props) {
  const [at, setAt] = useState('')
  const [pages, setPages] = useState('')
  const [durText, setDurText] = useState('')
  const [durUnit, setDurUnit] = useState<'min' | 'hour'>('min')
  const [progress, setProgress] = useState(0)
  const [pageStr, setPageStr] = useState('')
  const [note, setNote] = useState('')
  const [alsoFinish, setAlsoFinish] = useState(false)

  useEffect(() => {
    if (!open) return
    const init = roundProgress(book, round)
    setAt(toDateTimeInput())
    setPages('')
    setDurText('')
    setDurUnit('min')
    setProgress(init)
    setPageStr(
      book.totalPages ? String(Math.round((init / 100) * book.totalPages)) : '',
    )
    setNote('')
    setAlsoFinish(false)
  }, [open, book, round])

  const total = book.totalPages

  const setBoth = (p: number) => {
    const v = clamp(Math.round(p), 0, 100)
    setProgress(v)
    if (total) setPageStr(String(Math.round((v / 100) * total)))
    setAlsoFinish(v >= 100)
  }

  const onSlide = (v: number) => setBoth(v)

  const onPage = (v: string) => {
    setPageStr(v)
    const n = Number.parseFloat(v)
    if (total && Number.isFinite(n)) {
      const p = clamp(Math.round((n / total) * 100), 0, 100)
      setProgress(p)
      setAlsoFinish(p >= 100)
    }
  }

  const submit = () => {
    onSubmit(
      {
        at: fromInput(at),
        pages: parseNum(pages),
        minutes: toMinutes(durText, durUnit),
        progress,
        note: note.trim() || undefined,
      },
      alsoFinish,
    )
    onClose()
  }

  return (
    <Sheet
      open={open}
      title="记录本次阅读"
      subtitle={`第 ${round.index} 次阅读 · 《${book.title}》`}
      onClose={onClose}
      footer={
        <button className="btn primary block" onClick={submit}>
          保存记录
        </button>
      }
    >
      <div className="field">
        <label className="label">时间</label>
        <input
          className="input"
          type="datetime-local"
          value={at}
          onChange={(e) => setAt(e.target.value)}
        />
      </div>

      <div className="field">
        <label className="label">
          本次读了多少页<span className="opt">选填</span>
        </label>
        <div className="input-row">
          <input
            className="input"
            type="number"
            inputMode="numeric"
            min={0}
            placeholder="例如：30"
            value={pages}
            onChange={(e) => setPages(e.target.value)}
          />
          <span className="suffix">页</span>
        </div>
      </div>

      <div className="field">
        <label className="label">
          本次读了多久<span className="opt">选填</span>
        </label>
        <DurationField
          text={durText}
          unit={durUnit}
          onText={setDurText}
          onUnit={setDurUnit}
        />
      </div>

      <div className="field">
        <label className="label">读完这一段后的总进度</label>
        <div
          style={{
            display: 'flex',
            alignItems: 'baseline',
            gap: 10,
            marginBottom: 2,
          }}
        >
          <span className="progress-value">{progress}%</span>
          {total ? (
            <span className="suffix">
              约第 {Math.round((progress / 100) * total)} 页 / 共 {total} 页
            </span>
          ) : null}
        </div>
        <input
          className="slider"
          type="range"
          min={0}
          max={100}
          step={1}
          value={progress}
          onChange={(e) => onSlide(Number(e.target.value))}
        />

        {total ? (
          <div className="input-row">
            <input
              className="input"
              type="number"
              inputMode="numeric"
              min={0}
              max={total}
              placeholder="或直接填读到第几页"
              value={pageStr}
              onChange={(e) => onPage(e.target.value)}
            />
            <span className="suffix">页</span>
          </div>
        ) : null}

        <div className="chips" style={{ marginTop: 10 }}>
          {[25, 50, 75, 100].map((p) => (
            <button
              key={p}
              type="button"
              className={`chip${progress === p ? ' active' : ''}`}
              onClick={() => setBoth(p)}
            >
              {p === 100 ? '读完了' : `${p}%`}
            </button>
          ))}
        </div>
      </div>

      {progress >= 100 && (
        <div className="field">
          <button
            type="button"
            className={`chip${alsoFinish ? ' active' : ''}`}
            onClick={() => setAlsoFinish((v) => !v)}
            style={{ width: '100%', padding: '11px 13px', textAlign: 'left' }}
          >
            {alsoFinish ? '☑' : '☐'} 同时把这次标记为「读完」
          </button>
        </div>
      )}

      <div className="field">
        <label className="label">
          备注<span className="opt">选填</span>
        </label>
        <textarea
          className="input"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="印象最深的一段、金句、心情……"
        />
      </div>
    </Sheet>
  )
}
