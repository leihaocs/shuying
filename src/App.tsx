import { HashRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { StoreProvider } from './store'
import TabBar from './components/TabBar'
import BooksPage from './pages/BooksPage'
import BookDetailPage from './pages/BookDetailPage'
import MoviesPage from './pages/MoviesPage'
import MovieDetailPage from './pages/MovieDetailPage'
import StatsPage from './pages/StatsPage'

const TAB_ROUTES = ['/', '/movies', '/stats']

function Shell() {
  const { pathname } = useLocation()
  const showTabs = TAB_ROUTES.includes(pathname)

  return (
    <div className="app">
      <Routes>
        <Route path="/" element={<BooksPage />} />
        <Route path="/books/:id" element={<BookDetailPage />} />
        <Route path="/movies" element={<MoviesPage />} />
        <Route path="/movies/:id" element={<MovieDetailPage />} />
        <Route path="/stats" element={<StatsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      {showTabs && <TabBar />}
    </div>
  )
}

export default function App() {
  return (
    <StoreProvider>
      <HashRouter>
        <Shell />
      </HashRouter>
    </StoreProvider>
  )
}
