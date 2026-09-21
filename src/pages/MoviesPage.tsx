import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../store'
import { movieStatus, movieLastTouch } from '../lib/movies'
import MovieItem from '../components/MovieItem'
import MovieForm from '../components/forms/MovieForm'
import { EmptyState, Segmented, useToast } from '../components/Bits'

type Filter = 'all' | 'want' | 'watched'

export default function MoviesPage() {
  const navigate = useNavigate()
  const { movies, addMovie } = useStore()
  const [filter, setFilter] = useState<Filter>('all')
  const [addOpen, setAddOpen] = useState(false)
  const { toast, show } = useToast()

  const counts = useMemo(() => {
    const c: Record<Filter, number> = { all: movies.length, want: 0, watched: 0 }
    movies.forEach((m) => {
      c[movieStatus(m)] += 1
    })
    return c
  }, [movies])

  const list = useMemo(() => {
    const arr =
      filter === 'all' ? movies : movies.filter((m) => movieStatus(m) === filter)
    return [...arr].sort((a, b) =>
      movieLastTouch(b).localeCompare(movieLastTouch(a)),
    )
  }, [movies, filter])

  const watchTimes = useMemo(
    () => movies.reduce((s, m) => s + m.watches.length, 0),
    [movies],
  )

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <h1 className="page-title">电影</h1>
          <p className="page-sub">
            {movies.length} 部 · 观影 {watchTimes} 次
          </p>
        </div>
      </div>

      <Segmented<Filter>
        value={filter}
        onChange={setFilter}
        options={[
          { key: 'all', label: '全部', count: counts.all },
          { key: 'want', label: '想看', count: counts.want },
          { key: 'watched', label: '已看', count: counts.watched },
        ]}
      />

      <div className="section">
        {list.length === 0 ? (
          filter === 'all' ? (
            <EmptyState
              icon="🎬"
              title="还没有记录任何电影"
              desc="点右下角的 + 添加，只需要片名和导演"
            />
          ) : (
            <EmptyState icon="🗂" title="这个分类下还没有电影" />
          )
        ) : (
          <div className="list">
            {list.map((m) => (
              <MovieItem
                key={m.id}
                movie={m}
                onClick={() => navigate(`/movies/${m.id}`)}
              />
            ))}
          </div>
        )}
      </div>

      <button className="fab" onClick={() => setAddOpen(true)} aria-label="添加电影">
        +
      </button>

      <MovieForm
        open={addOpen}
        onClose={() => setAddOpen(false)}
        onSubmit={(input) => {
          const movie = addMovie(input)
          show(`《${movie.title}》已加入`)
        }}
      />

      {toast}
    </div>
  )
}
