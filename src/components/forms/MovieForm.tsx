import { useEffect, useState } from 'react'
import Sheet from '../Sheet'
import type { MovieInput } from '../../store'
import type { Movie } from '../../types'

interface Props {
  open: boolean
  onClose: () => void
  initial?: Movie
  onSubmit: (input: MovieInput) => void
}

export default function MovieForm({ open, onClose, initial, onSubmit }: Props) {
  const [title, setTitle] = useState('')
  const [director, setDirector] = useState('')
  const [year, setYear] = useState('')
  const [note, setNote] = useState('')
  const [err, setErr] = useState('')

  useEffect(() => {
    if (!open) return
    setTitle(initial?.title ?? '')
    setDirector(initial?.director ?? '')
    setYear(initial?.year ?? '')
    setNote(initial?.note ?? '')
    setErr('')
  }, [open, initial])

  const submit = () => {
    if (!title.trim()) return setErr('片名是必填的')
    if (!director.trim()) return setErr('导演是必填的')
    onSubmit({ title, director, year, note })
    onClose()
  }

  return (
    <Sheet
      open={open}
      title={initial ? '编辑电影' : '添加电影'}
      subtitle="只需要片名和导演"
      onClose={onClose}
      footer={
        <button className="btn primary block" onClick={submit}>
          {initial ? '保存修改' : '添加'}
        </button>
      }
    >
      <div className="field">
        <label className="label">
          片名<span className="req">*</span>
        </label>
        <input
          className="input"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="例如：肖申克的救赎"
          autoFocus={!initial}
        />
      </div>

      <div className="field">
        <label className="label">
          导演<span className="req">*</span>
        </label>
        <input
          className="input"
          value={director}
          onChange={(e) => setDirector(e.target.value)}
          placeholder="例如：弗兰克·德拉邦特"
        />
      </div>

      <div className="field">
        <label className="label">
          上映年份<span className="opt">选填</span>
        </label>
        <input
          className="input"
          value={year}
          onChange={(e) => setYear(e.target.value)}
          placeholder="例如：1994"
        />
      </div>

      <div className="field">
        <label className="label">
          备注<span className="opt">选填</span>
        </label>
        <textarea
          className="input"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="想看的原因、想重看的理由……"
        />
      </div>

      {err && <div className="err">{err}</div>}
    </Sheet>
  )
}
