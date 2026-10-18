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
import UserDetailPage from './pages/UserDetailPage'
import WorkersPage from './pages/WorkersPage'
import WorkerDetailPage from './pages/WorkerDetailPage'
import JobsPage from './pages/JobsPage'
import JobDetailPage from './pages/JobDetailPage'
import ReportsPage from './pages/ReportsPage'
import ReportDetailPage from './pages/ReportDetailPage'
import AnalyticsPage from './pages/AnalyticsPage'
import LanguagesPage from './pages/LanguagesPage'
import CategoriesPage from './pages/CategoriesPage'

function AdminRoute({ admin, children }: { admin: AdminUser | null; children: React.ReactNode }) {
  if (!admin) return <Navigate to="/login" replace />
  return <>{children}</>
}

export default function App() {
  const [admin, setAdmin] = useState<AdminUser | null>(null)
  const [checking, setChecking] = useState(true)

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
              <DashboardPage onSignOut={() => signOut()} />
            </AdminRoute>
          }
        >
          <Route index element={<AnalyticsPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="users/:id" element={<UserDetailPage />} />
          <Route path="workers" element={<WorkersPage />} />
          <Route path="workers/:id" element={<WorkerDetailPage />} />
          <Route path="jobs" element={<JobsPage />} />
          <Route path="jobs/:id" element={<JobDetailPage />} />
          <Route path="reports" element={<ReportsPage />} />
          <Route path="reports/:reportId" element={<ReportDetailPage />} />
          <Route path="languages" element={<LanguagesPage />} />
          <Route path="categories" element={<CategoriesPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}