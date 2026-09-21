import { useEffect, useState } from 'react'
import Sheet from '../Sheet'
import { ACCENTS, COVERS, type BookInput } from '../../store'
import type { Book } from '../../types'
import { parseNum } from '../../lib/utils'
import { AccentPicker, CoverPicker } from './shared'

interface Props {
  open: boolean
  onClose: () => void
  initial?: Book
  onSubmit: (input: BookInput) => void
}

export default function BookForm({ open, onClose, initial, onSubmit }: Props) {
  const [title, setTitle] = useState('')
  const [author, setAuthor] = useState('')
  const [totalPages, setTotalPages] = useState('')
  const [cover, setCover] = useState(COVERS[0])
  const [accent, setAccent] = useState(ACCENTS[0])
  const [note, setNote] = useState('')
  const [err, setErr] = useState('')

  useEffect(() => {
    if (!open) return
    const idx = Math.floor(Math.random() * COVERS.length)
    setTitle(initial?.title ?? '')
    setAuthor(initial?.author ?? '')
    setTotalPages(initial?.totalPages ? String(initial.totalPages) : '')
    setCover(initial?.cover ?? COVERS[idx])
    setAccent(initial?.accent ?? ACCENTS[idx % ACCENTS.length])
    setNote(initial?.note ?? '')
    setErr('')
  }, [open, initial])

  const submit = () => {
    if (!title.trim()) return setErr('书名是必填的')
    if (!author.trim()) return setErr('作者是必填的')
    onSubmit({
      title,
      author,
      totalPages: parseNum(totalPages),
      cover,
      accent,
      note,
    })
    onClose()
  }

  return (
    <Sheet
      open={open}
      title={initial ? '编辑书籍' : '添加书籍'}
      subtitle="书名与作者必填，其余都可以稍后补充"
      onClose={onClose}
      footer={
        <button className="btn primary block" onClick={submit}>
          {initial ? '保存修改' : '加入书架'}
        </button>
      }
    >
      <div className="field">
        <label className="label">
          书名<span className="req">*</span>
        </label>
        <input
          className="input"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="例如：活着"
          autoFocus={!initial}
        />
      </div>

      <div className="field">
        <label className="label">
          作者<span className="req">*</span>
        </label>
        <input
          className="input"
          value={author}
          onChange={(e) => setAuthor(e.target.value)}
          placeholder="例如：余华"
        />
      </div>

      <div className="field">
        <label className="label">
          总页数<span className="opt">选填</span>
        </label>
        <div className="input-row">
          <input
            className="input"
            type="number"
            inputMode="numeric"
            min={1}
            value={totalPages}
            onChange={(e) => setTotalPages(e.target.value)}
            placeholder="填写后可自动换算阅读进度"
          />
          <span className="suffix">页</span>
        </div>
      </div>

      <div className="field">
        <label className="label">封面</label>
        <CoverPicker value={cover} onChange={setCover} />
      </div>

      <div className="field">
        <label className="label">主题色</label>
        <AccentPicker value={accent} onChange={setAccent} />
      </div>

      <div className="field">
        <label className="label">
          备注<span className="opt">选填</span>
        </label>
        <textarea
          className="input"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="想读的理由、版本信息……"
        />
      </div>

      {err && <div className="err">{err}</div>}
    </Sheet>
  )
}
