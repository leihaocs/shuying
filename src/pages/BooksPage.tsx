import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../store'
import type { BookStatus } from '../types'
import { bookLastTouch, bookStatus, bookSummary } from '../lib/books'
import BookItem from '../components/BookItem'
import BookForm from '../components/forms/BookForm'
import { EmptyState, Segmented, useToast } from '../components/Bits'

type Filter = 'all' | BookStatus

export default function BooksPage() {
  const navigate = useNavigate()
  const { books, addBook, toggleTheme, theme } = useStore()
  const [filter, setFilter] = useState<Filter>('all')
  const [addOpen, setAddOpen] = useState(false)
  const { toast, show } = useToast()

  const counts = useMemo(() => {
    const c: Record<Filter, number> = {
      all: books.length,
      want: 0,
      reading: 0,
      rereading: 0,
      finished: 0,
    }
    books.forEach((b) => {
      c[bookStatus(b)] += 1
    })
    return c
  }, [books])

  const list = useMemo(() => {
    const arr =
      filter === 'all' ? books : books.filter((b) => bookStatus(b) === filter)
    return [...arr].sort((a, b) => bookLastTouch(b).localeCompare(bookLastTouch(a)))
  }, [books, filter])

  const totalMinutes = useMemo(
    () => books.reduce((s, b) => s + bookSummary(b).totalMinutes, 0),
    [books],
  )
  const readTimes = useMemo(
    () => books.reduce((s, b) => s + bookSummary(b).readTimes, 0),
    [books],
  )

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <h1 className="page-title">书架</h1>
          <p className="page-sub">
            {books.length} 本书 · 读完 {readTimes} 次 ·{' '}
            {totalMinutes > 0 ? `共 ${Math.round(totalMinutes / 60)} 小时` : '还没有阅读时长'}
          </p>
        </div>
        <button
          className="icon-btn"
          onClick={toggleTheme}
          aria-label="切换主题"
          title="切换深浅色"
        >
          {theme === 'dark' ? '☀️' : '🌙'}
        </button>
      </div>

      <Segmented<Filter>
        value={filter}
        onChange={setFilter}
        options={[
          { key: 'all', label: '全部', count: counts.all },
          { key: 'want', label: '想读', count: counts.want },
          { key: 'reading', label: '在读', count: counts.reading },
          { key: 'rereading', label: '再次阅读', count: counts.rereading },
          { key: 'finished', label: '已读', count: counts.finished },
        ]}
      />

      <div className="section">
        {list.length === 0 ? (
          filter === 'all' ? (
            <EmptyState
              icon="📚"
              title="书架还是空的"
              desc="点右下角的 + 添加第一本书，只需要书名和作者"
            />
          ) : (
            <EmptyState icon="🗂" title="这个分类下还没有书" />
          )
        ) : (
          <div className="list">
            {list.map((b) => (
              <BookItem
                key={b.id}
                book={b}
                onClick={() => navigate(`/books/${b.id}`)}
              />
            ))}
          </div>
        )}
      </div>

      <button className="fab" onClick={() => setAddOpen(true)} aria-label="添加书籍">
        +
      </button>

      <BookForm
        open={addOpen}
        onClose={() => setAddOpen(false)}
        onSubmit={(input) => {
          const book = addBook(input)
          show(`《${book.title}》已加入书架`)
        }}
      />

      {toast}
    </div>
  )
}
