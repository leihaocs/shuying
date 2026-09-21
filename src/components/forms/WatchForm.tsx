import { useEffect, useState } from 'react'
import Sheet from '../Sheet'
import type { WatchRecord } from '../../types'
import { Stars } from '../Bits'
import { fromInput, toDateTimeInput } from '../../lib/utils'

interface Props {
  open: boolean
  onClose: () => void
  title: string
  subtitle?: string
  onSubmit: (watch: Omit<WatchRecord, 'id'>) => void
}

export default function WatchForm({
  open,
  onClose,
  title,
  subtitle,
  onSubmit,
}: Props) {
  const [at, setAt] = useState('')
  const [rating, setRating] = useState(0)
  const [note, setNote] = useState('')

  useEffect(() => {
    if (!open) return
    setAt(toDateTimeInput())
    setRating(0)
    setNote('')
  }, [open])

  return (
    <Sheet
      open={open}
      title={title}
      subtitle={subtitle}
      onClose={onClose}
      footer={
        <button
          className="btn primary block"
          onClick={() => {
            onSubmit({
              at: fromInput(at),
              rating: rating || undefined,
              note: note.trim() || undefined,
            })
            onClose()
          }}
        >
          保存记录
        </button>
      }
    >
      <div className="field">
        <label className="label">观看时间</label>
        <input
          className="input"
          type="datetime-local"
          value={at}
          onChange={(e) => setAt(e.target.value)}
        />
      </div>

      <div className="field">
        <label className="label">
          评分<span className="opt">选填</span>
        </label>
        <Stars value={rating} onChange={setRating} />
      </div>

      <div className="field">
        <label className="label">
          备注<span className="opt">选填</span>
        </label>
        <textarea
          className="input"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="观后感、印象最深的镜头……"
        />
      </div>
    </Sheet>
  )
}
