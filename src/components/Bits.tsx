import { useEffect, useState } from 'react'
import Sheet from './Sheet'

/* ------------------------------ 分段筛选 ------------------------------ */

interface SegmentedProps<T extends string> {
  value: T
  onChange: (v: T) => void
  options: { key: T; label: string; count?: number }[]
}

export function Segmented<T extends string>({
  value,
  onChange,
  options,
}: SegmentedProps<T>) {
  return (
    <div className="segmented">
      {options.map((o) => (
        <button
          key={o.key}
          className={`seg${value === o.key ? ' active' : ''}`}
          onClick={() => onChange(o.key)}
        >
          {o.label}
          {typeof o.count === 'number' && <span className="seg-count">{o.count}</span>}
        </button>
      ))}
    </div>
  )
}

/* ------------------------------ 星级 ------------------------------ */

export function Stars({
  value,
  onChange,
  size = 24,
}: {
  value: number
  onChange?: (v: number) => void
  size?: number
}) {
  return (
    <div className="stars" style={{ fontSize: size }}>
      {[1, 2, 3, 4, 5].map((i) =>
        onChange ? (
          <button
            key={i}
            type="button"
            className={`star${i <= value ? ' on' : ''}`}
            onClick={() => onChange(value === i ? 0 : i)}
            aria-label={`${i} 星`}
          >
            ★
          </button>
        ) : (
          <span key={i} className={`star${i <= value ? ' on' : ''}`}>
            ★
          </span>
        ),
      )}
    </div>
  )
}

/* ------------------------------ 空状态 ------------------------------ */

export function EmptyState({
  icon,
  title,
  desc,
}: {
  icon: string
  title: string
  desc?: string
}) {
  return (
    <div className="empty">
      <div className="empty-icon">{icon}</div>
      <div className="empty-title">{title}</div>
      {desc && <div className="empty-desc">{desc}</div>}
    </div>
  )
}

/* ------------------------------ 轻提示 ------------------------------ */

export function useToast() {
  const [msg, setMsg] = useState<string | null>(null)

  useEffect(() => {
    if (!msg) return
    const t = setTimeout(() => setMsg(null), 1700)
    return () => clearTimeout(t)
  }, [msg])

  const toast = msg ? <div className="toast">{msg}</div> : null
  return { toast, show: setMsg }
}

/* ------------------------------ 确认框 ------------------------------ */

export function Confirm({
  open,
  title,
  desc,
  confirmText = '删除',
  danger = true,
  onCancel,
  onConfirm,
}: {
  open: boolean
  title: string
  desc?: string
  confirmText?: string
  danger?: boolean
  onCancel: () => void
  onConfirm: () => void
}) {
  return (
    <Sheet
      open={open}
      title={title}
      subtitle={desc}
      onClose={onCancel}
      footer={
        <div className="btn-row">
          <button className="btn ghost" onClick={onCancel}>
            取消
          </button>
          <button
            className={`btn ${danger ? 'danger' : 'primary'}`}
            onClick={() => {
              onConfirm()
              onCancel()
            }}
          >
            {confirmText}
          </button>
        </div>
      }
    >
      <div style={{ height: 6 }} />
    </Sheet>
  )
}
