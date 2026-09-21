import type { Movie, MovieStatus, WatchRecord } from '../types'

export function movieStatus(movie: Movie): MovieStatus {
  return movie.watches.length === 0 ? 'want' : 'watched'
}

export function movieStatusLabel(movie: Movie): string {
  return movie.watches.length === 0 ? '想看' : `已看${movie.watches.length}次`
}

export function sortedWatches(movie: Movie): WatchRecord[] {
  return [...movie.watches].sort((a, b) => b.at.localeCompare(a.at))
}

export function lastWatch(movie: Movie): WatchRecord | undefined {
  return sortedWatches(movie)[0]
}

/** 最近一次观看时间 */
export function movieLastTouch(movie: Movie): string {
  return lastWatch(movie)?.at || movie.createdAt
}
