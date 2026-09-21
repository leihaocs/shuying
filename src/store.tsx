import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import type { Book, Movie, ReadingLog, ReadingRound, WatchRecord } from './types'
import { nowISO, uid } from './lib/utils'

export type Theme = 'light' | 'dark'

export const COVERS = ['📕', '📗', '📘', '📙', '📖', '📚', '📔', '📓', '🧠', '🌿', '🎯', '🕯️']
export const ACCENTS = [
  '#b4552d',
  '#3f7d54',
  '#3a6ea5',
  '#8a5a9b',
  '#c2872f',
  '#2f8a8a',
  '#a5453a',
  '#5b6bb5',
]

interface AppState {
  books: Book[]
  movies: Movie[]
  theme: Theme
}

const STORAGE_KEY = 'shuying.state.v1'

/* ------------------------------------------------------------------ */
/* 初始数据（首次打开时的示例，可一键删除）                             */
/* ------------------------------------------------------------------ */

function seedState(): AppState {
  const at = (dayAgo: number, hour = 21, minute = 30) => {
    const d = new Date()
    d.setDate(d.getDate() - dayAgo)
    d.setHours(hour, minute, 0, 0)
    return d.toISOString()
  }

  const book: Book = {
    id: uid('bk_'),
    title: '活着',
    author: '余华',
    totalPages: 191,
    cover: '📕',
    accent: ACCENTS[0],
    createdAt: at(20, 10, 0),
    updatedAt: at(1),
    rounds: [
      {
        id: uid('rd_'),
        index: 1,
        startedAt: at(12),
        logs: [
          { id: uid('lg_'), at: at(12), pages: 46, minutes: 52, progress: 24, note: '开篇就很抓人。' },
          { id: uid('lg_'), at: at(6), pages: 58, minutes: 61, progress: 55 },
          { id: uid('lg_'), at: at(1), pages: 41, minutes: 45, progress: 76 },
        ],
      },
    ],
  }

  const want: Book = {
    id: uid('bk_'),
    title: '百年孤独',
    author: '加西亚·马尔克斯',
    totalPages: 360,
    cover: '📘',
    accent: ACCENTS[2],
    createdAt: at(9, 15, 20),
    updatedAt: at(9, 15, 20),
    rounds: [],
  }

  const movie: Movie = {
    id: uid('mv_'),
    title: '肖申克的救赎',
    director: '弗兰克·德拉邦特',
    year: '1994',
    createdAt: at(30, 20, 0),
    updatedAt: at(3, 20, 0),
    watches: [
      { id: uid('wt_'), at: at(30, 20, 0), rating: 5, note: '希望是件好事，也许是世间最好的事。' },
      { id: uid('wt_'), at: at(3, 20, 0), rating: 5 },
    ],
  }

  return { books: [book, want], movies: [movie], theme: 'light' }
}

function loadState(): AppState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return seedState()
    const parsed = JSON.parse(raw) as Partial<AppState>
    return {
      books: Array.isArray(parsed.books) ? parsed.books : [],
      movies: Array.isArray(parsed.movies) ? parsed.movies : [],
      theme: parsed.theme === 'dark' ? 'dark' : 'light',
    }
  } catch {
    return { books: [], movies: [], theme: 'light' }
  }
}

/* ------------------------------------------------------------------ */
/* Store                                                              */
/* ------------------------------------------------------------------ */

export interface BookInput {
  title: string
  author: string
  totalPages?: number
  cover?: string
  accent?: string
  note?: string
}

export interface MovieInput {
  title: string
  director: string
  year?: string
  note?: string
}

export interface LogInput {
  at: string
  pages?: number
  minutes?: number
  progress?: number
  note?: string
}

export interface PastRoundInput {
  startedAt: string
  finishedAt: string
  pages?: number
  minutes?: number
  note?: string
}

interface StoreValue {
  books: Book[]
  movies: Movie[]
  theme: Theme
  toggleTheme: () => void
  /* 书籍 */
  addBook: (input: BookInput) => Book
  updateBook: (id: string, input: BookInput) => void
  removeBook: (id: string) => void
  startReading: (bookId: string) => void
  addLog: (bookId: string, roundId: string, log: LogInput) => void
  removeLog: (bookId: string, logId: string) => void
  finishRound: (bookId: string, roundId: string) => void
  addPastRound: (bookId: string, input: PastRoundInput) => void
  removeRound: (bookId: string, roundId: string) => void
  /* 电影 */
  addMovie: (input: MovieInput) => Movie
  updateMovie: (id: string, input: MovieInput) => void
  removeMovie: (id: string) => void
  addWatch: (movieId: string, watch: Omit<WatchRecord, 'id'>) => void
  removeWatch: (movieId: string, watchId: string) => void
}

const StoreContext = createContext<StoreValue | null>(null)

export function StoreProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AppState>(loadState)

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
    } catch {
      /* 存储不可用时忽略 */
    }
  }, [state])

  useEffect(() => {
    document.documentElement.dataset.theme = state.theme
    const meta = document.querySelector('meta[name="theme-color"]')
    if (meta) {
      meta.setAttribute('content', state.theme === 'dark' ? '#14130f' : '#f7f4ef')
    }
  }, [state.theme])

  /** 通用：按 id 修改某本书 */
  const patchBook = useCallback((id: string, fn: (b: Book) => Book) => {
    setState((s) => ({
      ...s,
      books: s.books.map((b) =>
        b.id === id ? { ...fn(b), updatedAt: nowISO() } : b,
      ),
    }))
  }, [])

  const value = useMemo<StoreValue>(() => {
    return {
      books: state.books,
      movies: state.movies,
      theme: state.theme,

      toggleTheme: () =>
        setState((s) => ({ ...s, theme: s.theme === 'dark' ? 'light' : 'dark' })),

      /* ---------------- 书籍 ---------------- */

      addBook: (input) => {
        const book: Book = {
          id: uid('bk_'),
          title: input.title.trim(),
          author: input.author.trim(),
          totalPages: input.totalPages,
          cover: input.cover || '📖',
          accent: input.accent || ACCENTS[0],
          note: input.note?.trim() || undefined,
          createdAt: nowISO(),
          updatedAt: nowISO(),
          rounds: [],
        }
        setState((s) => ({ ...s, books: [book, ...s.books] }))
        return book
      },

      updateBook: (id, input) =>
        patchBook(id, (b) => ({
          ...b,
          title: input.title.trim(),
          author: input.author.trim(),
          totalPages: input.totalPages,
          cover: input.cover || b.cover,
          accent: input.accent || b.accent,
          note: input.note?.trim() || undefined,
        })),

      removeBook: (id) =>
        setState((s) => ({ ...s, books: s.books.filter((b) => b.id !== id) })),

      /** 想读 -> 开始第一轮阅读 */
      startReading: (bookId) =>
        patchBook(bookId, (b) => {
          if (b.rounds.some((r) => !r.finishedAt)) return b
          const round: ReadingRound = {
            id: uid('rd_'),
            index: b.rounds.length + 1,
            startedAt: nowISO(),
            logs: [],
          }
          return { ...b, rounds: [...b.rounds, round] }
        }),

      addLog: (bookId, roundId, log) =>
        patchBook(bookId, (b) => ({
          ...b,
          rounds: b.rounds.map((r) =>
            r.id === roundId
              ? { ...r, logs: [...r.logs, { ...log, id: uid('lg_') }] }
              : r,
          ),
        })),

      removeLog: (bookId, logId) =>
        patchBook(bookId, (b) => ({
          ...b,
          rounds: b.rounds.map((r) => ({
            ...r,
            logs: r.logs.filter((l) => l.id !== logId),
          })),
        })),

      /** 标记读完当前这一轮 */
      finishRound: (bookId, roundId) =>
        patchBook(bookId, (b) => ({
          ...b,
          rounds: b.rounds.map((r) =>
            r.id === roundId && !r.finishedAt
              ? { ...r, finishedAt: nowISO() }
              : r,
          ),
        })),

      /** 补记往期已读（含起止时间） */
      addPastRound: (bookId, input) =>
        patchBook(bookId, (b) => {
          const log: ReadingLog | null =
            input.pages || input.minutes || input.note
              ? {
                  id: uid('lg_'),
                  at: input.finishedAt,
                  pages: input.pages,
                  minutes: input.minutes,
                  progress: 100,
                  note: input.note?.trim() || undefined,
                }
              : null
          const round: ReadingRound = {
            id: uid('rd_'),
            index: b.rounds.length + 1,
            startedAt: input.startedAt,
            finishedAt: input.finishedAt,
            logs: log ? [log] : [],
          }
          return { ...b, rounds: [...b.rounds, round] }
        }),

      removeRound: (bookId, roundId) =>
        patchBook(bookId, (b) => ({
          ...b,
          rounds: b.rounds
            .filter((r) => r.id !== roundId)
            .map((r, i) => ({ ...r, index: i + 1 })),
        })),

      /* ---------------- 电影 ---------------- */

      addMovie: (input) => {
        const movie: Movie = {
          id: uid('mv_'),
          title: input.title.trim(),
          director: input.director.trim(),
          year: input.year?.trim() || undefined,
          note: input.note?.trim() || undefined,
          createdAt: nowISO(),
          updatedAt: nowISO(),
          watches: [],
        }
        setState((s) => ({ ...s, movies: [movie, ...s.movies] }))
        return movie
      },

      updateMovie: (id, input) =>
        setState((s) => ({
          ...s,
          movies: s.movies.map((m) =>
            m.id === id
              ? {
                  ...m,
                  title: input.title.trim(),
                  director: input.director.trim(),
                  year: input.year?.trim() || undefined,
                  note: input.note?.trim() || undefined,
                  updatedAt: nowISO(),
                }
              : m,
          ),
        })),

      removeMovie: (id) =>
        setState((s) => ({ ...s, movies: s.movies.filter((m) => m.id !== id) })),

      addWatch: (movieId, watch) =>
        setState((s) => ({
          ...s,
          movies: s.movies.map((m) =>
            m.id === movieId
              ? {
                  ...m,
                  updatedAt: nowISO(),
                  watches: [...m.watches, { ...watch, id: uid('wt_') }],
                }
              : m,
          ),
        })),

      removeWatch: (movieId, watchId) =>
        setState((s) => ({
          ...s,
          movies: s.movies.map((m) =>
            m.id === movieId
              ? {
                  ...m,
                  updatedAt: nowISO(),
                  watches: m.watches.filter((w) => w.id !== watchId),
                }
              : m,
          ),
        })),
    }
  }, [state, patchBook])

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>
}

export function useStore(): StoreValue {
  const ctx = useContext(StoreContext)
  if (!ctx) throw new Error('useStore 必须在 StoreProvider 内使用')
  return ctx
}
