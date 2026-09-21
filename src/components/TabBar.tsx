import { NavLink } from 'react-router-dom'

const TABS = [
  { to: '/', icon: '📖', label: '书架' },
  { to: '/movies', icon: '🎬', label: '电影' },
  { to: '/stats', icon: '📊', label: '统计' },
]

export default function TabBar() {
  return (
    <nav className="tabbar">
      {TABS.map((t) => (
        <NavLink
          key={t.to}
          to={t.to}
          end={t.to === '/'}
          className={({ isActive }) => `tab${isActive ? ' active' : ''}`}
        >
          <span className="tab-icon">{t.icon}</span>
          <span>{t.label}</span>
        </NavLink>
      ))}
    </nav>
  )
}
