import { Outlet, useLocation, useNavigate } from 'react-router-dom'

const brandBlue = '#004F9F'
const accentYellow = '#FFB800'

interface DashboardPageProps {
  onSignOut: () => void
}

const navItems = [
  { key: 'dashboard', label: 'Analytics', path: '/' },
  { key: 'users', label: 'Users', path: '/users' },
  { key: 'workers', label: 'Workers', path: '/workers' },
  { key: 'jobs', label: 'Jobs', path: '/jobs' },
  { key: 'reports', label: 'Reports', path: '/reports' },
  { key: 'languages', label: 'Languages', path: '/languages' },
  { key: 'categories', label: 'Categories', path: '/categories' },
]

/** Prefix match so detail pages (e.g. /users/u123) keep their list's nav item active. */
function pathMatches(path: string, pathname: string): boolean {
  if (path === '/') return pathname === '/'
  return pathname === path || pathname.startsWith(`${path}/`)
}

export default function DashboardPage({ onSignOut }: DashboardPageProps) {
  // Nav is driven by the URL: the active item is derived from the current
  // route, and clicks perform real router navigation (not just a highlight),
  // so deep links and refreshes on a sub-URL land on the right page.
  const navigate = useNavigate()
  const location = useLocation()
  const current =
    navItems.find((item) => pathMatches(item.path, location.pathname))?.key ?? 'dashboard'

  return (
    <div style={{ fontFamily: 'system-ui, sans-serif', minHeight: '100vh', background: '#F4F6F9' }}>
      <header
        style={{
          background: brandBlue,
          color: '#fff',
          padding: '0 32px',
          height: 60,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div
            style={{
              width: 32,
              height: 32,
              borderRadius: '50%',
              background: accentYellow,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontWeight: 800,
              color: brandBlue,
            }}
          >
            Q
          </div>
          <span style={{ fontWeight: 800, fontSize: 16 }}>QuickFix Admin</span>
        </div>
        <div style={{ display: 'flex', gap: 24, alignItems: 'center' }}>
          {navItems.map((item) => (
            <button
              key={item.key}
              onClick={() => navigate(item.path)}
              style={{
                background: 'transparent',
                border: 'none',
                color: current === item.key ? accentYellow : 'rgba(255,255,255,0.75)',
                fontWeight: current === item.key ? 700 : 500,
                fontSize: 13,
                cursor: 'pointer',
                padding: '6px 2px',
                borderBottom: current === item.key ? `2px solid ${accentYellow}` : '2px solid transparent',
              }}
            >
              {item.label}
            </button>
          ))}
          <button
            onClick={onSignOut}
            style={{
              background: 'transparent',
              border: '1px solid rgba(255,255,255,0.4)',
              color: '#fff',
              borderRadius: 10,
              padding: '8px 16px',
              cursor: 'pointer',
              fontSize: 13,
            }}
          >
            Sign out
          </button>
        </div>
      </header>
      <main style={{ padding: 32 }}>
        <Outlet />
      </main>
    </div>
  )
}
