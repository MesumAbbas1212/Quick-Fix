import { useEffect, useState } from 'react'
import {
  BrowserRouter,
  Navigate,
  Route,
  Routes,
} from 'react-router-dom'
import { getAdminInfo, onAuthChange, signOut } from './api/auth'
import type { AdminUser } from './api/auth'
import LoginPage from './pages/LoginPage'
import DashboardPage from './pages/DashboardPage'
import UsersPage from './pages/UsersPage'
import WorkersPage from './pages/WorkersPage'
import JobsPage from './pages/JobsPage'
import ReportsPage from './pages/ReportsPage'
import AnalyticsPage from './pages/AnalyticsPage'

function AdminRoute({ admin, children }: { admin: AdminUser | null; children: React.ReactNode }) {
  if (!admin) return <Navigate to="/login" replace />
  return <>{children}</>
}

export default function App() {
  const [admin, setAdmin] = useState<AdminUser | null>(null)
  const [checking, setChecking] = useState(true)
  const [current, setCurrent] = useState('dashboard')

  useEffect(() => {
    const unsub = onAuthChange(async (user) => {
      if (!user) {
        setAdmin(null)
        setChecking(false)
        return
      }
      const info = await getAdminInfo(user.uid)
      setAdmin(info)
      setChecking(false)
    })
    return unsub
  }, [])

  if (checking) {
    return (
      <div
        style={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontFamily: 'system-ui, sans-serif',
          color: '#64748B',
        }}
      >
        Checking access…
      </div>
    )
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={admin ? <Navigate to="/" replace /> : <LoginPage />} />
        <Route
          path="/"
          element={
            <AdminRoute admin={admin}>
              <DashboardPage onSignOut={() => signOut()} current={current} onNavigate={setCurrent} />
            </AdminRoute>
          }
        >
          <Route index element={<AnalyticsPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="workers" element={<WorkersPage />} />
          <Route path="jobs" element={<JobsPage />} />
          <Route path="reports" element={<ReportsPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}