/** 一次阅读记录（某天读了多少页 / 多久 / 读完后的总进度） */
export interface ReadingLog {
  id: string
  /** 记录时间 */
  at: string
  /** 本次读了多少页 */
  pages?: number
  /** 本次读了多久（分钟） */
  minutes?: number
  /** 本次结束后的总进度（0-100） */
  progress?: number
  /** 备注 */
  note?: string
}

/** 一轮阅读（从开始读一本，到读完为止；同一本书可以有多轮 = 多次阅读） */
export interface ReadingRound {
  id: string
  /** 第几次阅读，从 1 开始 */
  index: number
  startedAt: string
  /** 为空表示这一轮还没读完 */
  finishedAt?: string
  /** 补记往期阅读时，可跳过细节，直接给汇总值 */
  logs: ReadingLog[]
}

export interface Book {
  id: string
  title: string
  author: string
  /** 选填：总页数 */
  totalPages?: number
  /** 封面 emoji */
  cover: string
  /** 主题色 */
  accent: string
  note?: string
  createdAt: string
  updatedAt: string
  rounds: ReadingRound[]
}

export type BookStatus = 'want' | 'reading' | 'rereading' | 'finished'

/** 一次观影记录 */
export interface WatchRecord {
  id: string
  /** 观看时间 */
  at: string
  /** 一星到五星 */
  rating?: number
  note?: string
}

export interface Movie {
  id: string
  title: string
  director: string
  year?: string
  note?: string
  createdAt: string
  updatedAt: string
  watches: WatchRecord[]
}

export type MovieStatus = 'want' | 'watched'
