export function uid(prefix = ''): string {
  return (
    prefix +
    Math.random().toString(36).slice(2, 9) +
    Date.now().toString(36).slice(-4)
  )
}

export function nowISO(): string {
  return new Date().toISOString()
}

function pad(n: number): string {
  return n < 10 ? `0${n}` : String(n)
}

/** ISO -> datetime-local 输入框需要的本地时间字符串 */
export function toDateTimeInput(iso?: string): string {
  const d = iso ? new Date(iso) : new Date()
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours(),
  )}:${pad(d.getMinutes())}`
}

/** ISO -> date 输入框需要的本地日期字符串 */
export function toDateInput(iso?: string): string {
  const d = iso ? new Date(iso) : new Date()
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export function fromInput(value: string): string {
  // 纯日期按本地时区中午解析，避免 UTC 偏移导致日期前后跳动
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const [y, m, d] = value.split('-').map(Number)
    return new Date(y, m - 1, d, 12, 0, 0, 0).toISOString()
  }
  const d = new Date(value)
  return isNaN(d.getTime()) ? nowISO() : d.toISOString()
}

export function formatDate(iso?: string): string {
  if (!iso) return '—'
  const d = new Date(iso)
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export function formatDateTime(iso?: string): string {
  if (!iso) return '—'
  const d = new Date(iso)
  return `${formatDate(iso)} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

export function relativeDay(iso?: string): string {
  if (!iso) return '—'
  const d = new Date(iso)
  const now = new Date()
  const a = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
  const b = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  const diff = Math.round((b - a) / 86400000)
  if (diff === 0) return '今天'
  if (diff === 1) return '昨天'
  if (diff === 2) return '前天'
  if (diff > 0 && diff < 7) return `${diff}天前`
  return formatDate(iso)
}

export function formatDuration(minutes?: number): string {
  if (!minutes || minutes <= 0) return '—'
  const h = Math.floor(minutes / 60)
  const m = Math.round(minutes % 60)
  if (h && m) return `${h}小时${m}分`
  if (h) return `${h}小时`
  return `${m}分钟`
}

export function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, v))
}

export function parseNum(v: string): number | undefined {
  const n = Number.parseFloat(v)
  return Number.isFinite(n) && n > 0 ? n : undefined
}
