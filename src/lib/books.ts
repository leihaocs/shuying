import type { Book, BookStatus, ReadingLog, ReadingRound } from '../types'

/** 当前正在进行、尚未读完的一轮阅读 */
export function activeRound(book: Book): ReadingRound | undefined {
  return book.rounds.find((r) => !r.finishedAt)
}

/** 已读完的轮次，按时间倒序 */
export function finishedRounds(book: Book): ReadingRound[] {
  return book.rounds
    .filter((r) => r.finishedAt)
    .sort((a, b) => (b.finishedAt || '').localeCompare(a.finishedAt || ''))
}

/**
 * 书籍状态推导
 * - 没有任何轮次          -> 想读
 * - 有未读完的第 1 轮      -> 在读
 * - 有未读完的第 N 轮(N>1) -> 再次阅读
 * - 所有轮次都已读完       -> 已读N次
 */
export function bookStatus(book: Book): BookStatus {
  const active = activeRound(book)
  if (active) return active.index <= 1 ? 'reading' : 'rereading'
  return book.rounds.length === 0 ? 'want' : 'finished'
}

export function statusLabel(book: Book): string {
  const s = bookStatus(book)
  if (s === 'want') return '想读'
  if (s === 'reading') return '在读'
  if (s === 'rereading') return '再次阅读'
  return `已读${book.rounds.length}次`
}

export function roundPages(round: ReadingRound): number {
  return round.logs.reduce((sum, l) => sum + (l.pages || 0), 0)
}

export function roundMinutes(round: ReadingRound): number {
  return round.logs.reduce((sum, l) => sum + (l.minutes || 0), 0)
}

export function roundLogCount(round: ReadingRound): number {
  return round.logs.length
}

export function sortedLogs(round: ReadingRound): ReadingLog[] {
  return [...round.logs].sort((a, b) => b.at.localeCompare(a.at))
}

/** 当前进度：优先取最近一次显式填写的进度，否则按页数估算 */
export function roundProgress(book: Book, round?: ReadingRound): number {
  if (!round) return 0
  const explicit = [...round.logs]
    .reverse()
    .find((l) => typeof l.progress === 'number')
  if (explicit) return Math.round(clamp01(explicit.progress as number))
  if (book.totalPages) {
    return Math.round((roundPages(round) / book.totalPages) * 100)
  }
  return 0
}

function clamp01(v: number): number {
  return Math.max(0, Math.min(100, v))
}

/** 全书汇总 */
export function bookSummary(book: Book) {
  const totalPages = book.rounds.reduce((s, r) => s + roundPages(r), 0)
  const totalMinutes = book.rounds.reduce((s, r) => s + roundMinutes(r), 0)
  const totalLogs = book.rounds.reduce((s, r) => s + r.logs.length, 0)
  const lastLog = book.rounds
    .flatMap((r) => r.logs)
    .sort((a, b) => b.at.localeCompare(a.at))[0]
  const done = finishedRounds(book)
  return {
    readTimes: done.length,
    totalPages,
    totalMinutes,
    totalLogs,
    lastLogAt: lastLog?.at,
    lastFinishedAt: done[0]?.finishedAt,
  }
}

/** 最近一次接触这本书的时间（用于排序） */
export function bookLastTouch(book: Book): string {
  const last = book.rounds
    .flatMap((r) => r.logs.map((l) => l.at).concat(r.finishedAt || []))
    .sort()
    .pop()
  return last || book.createdAt
}
