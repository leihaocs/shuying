import { useEffect, useState } from 'react'
import Sheet from '../Sheet'
import type { PastRoundInput } from '../../store'
import { fromInput, parseNum, toDateInput } from '../../lib/utils'
import { DurationField, toMinutes } from './shared'

interface Props {
  open: boolean
  onClose: () => void
  bookTitle: string
  onSubmit: (input: PastRoundInput) => void
}

/** 补记以前已经读完的那几次（含起止时间） */
export default function PastRoundForm({
  open,
  onClose,
  bookTitle,
  onSubmit,
}: Props) {
  const [startedAt, setStartedAt] = useState('')
  const [finishedAt, setFinishedAt] = useState('')
  const [pages, setPages] = useState('')
  const [durText, setDurText] = useState('')
  const [durUnit, setDurUnit] = useState<'min' | 'hour'>('hour')
  const [note, setNote] = useState('')
  const [err, setErr] = useState('')

  useEffect(() => {
    if (!open) return
    setStartedAt(toDateInput())
    setFinishedAt(toDateInput())
    setPages('')
    setDurText('')
    setDurUnit('hour')
    setNote('')
    setErr('')
  }, [open])

  const submit = () => {
    const s = fromInput(startedAt)
    const f = fromInput(finishedAt)
    if (new Date(f).getTime() < new Date(s).getTime()) {
      return setErr('读完的时间不能早于开始的时间')
    }
    onSubmit({
      startedAt: s,
      finishedAt: f,
      pages: parseNum(pages),
      minutes: toMinutes(durText, durUnit),
      note,
    })
    onClose()
  }

  return (
    <Sheet
      open={open}
      title="补记往期阅读"
      subtitle={`把《${bookTitle}》以前读完的那几次补上`}
      onClose={onClose}
      footer={
        <button className="btn primary block" onClick={submit}>
          保存这次阅读
        </button>
      }
    >
      <div className="field">
        <label className="label">开始阅读</label>
        <input
          className="input"
          type="date"
          value={startedAt}
          onChange={(e) => setStartedAt(e.target.value)}
        />
      </div>

      <div className="field">
        <label className="label">读完时间</label>
        <input
          className="input"
          type="date"
          value={finishedAt}
          onChange={(e) => setFinishedAt(e.target.value)}
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
            min={0}
            placeholder="这次一共读了多少页"
            value={pages}
            onChange={(e) => setPages(e.target.value)}
          />
          <span className="suffix">页</span>
        </div>
      </div>

      <div className="field">
        <label className="label">
          总时长<span className="opt">选填</span>
        </label>
        <DurationField
          text={durText}
          unit={durUnit}
          onText={setDurText}
          onUnit={setDurUnit}
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
          placeholder="这一遍读下来的感受……"
        />
      </div>

      {err && <div className="err">{err}</div>}
    </Sheet>
  )
}
