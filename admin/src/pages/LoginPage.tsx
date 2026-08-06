import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { signIn } from '../api/auth'

const brandBlue = '#004F9F'
const accentYellow = '#FFB800'
const ctaOrange = '#F36C00'

export default function LoginPage() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      await signIn(email, password)
      navigate('/')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div
      style={{
        minHeight: '100vh',
        background: brandBlue,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: 'system-ui, sans-serif',
      }}
    >
      <form
        onSubmit={handleSubmit}
        style={{
          width: 380,
          background: '#fff',
          borderRadius: 24,
          padding: 36,
          boxShadow: '0 20px 50px rgba(0,0,0,0.25)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
          <div
            style={{
              width: 40,
              height: 40,
              borderRadius: '50%',
              background: accentYellow,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontWeight: 800,
              color: brandBlue,
              fontSize: 18,
            }}
          >
            Q
          </div>
          <h1 style={{ fontSize: 26, fontWeight: 800, color: brandBlue, margin: 0 }}>
            Quick<span style={{ color: accentYellow }}>Fix</span>
          </h1>
        </div>
        <p style={{ color: '#64748B', fontSize: 13, margin: '4px 0 24px' }}>
          Admin Dashboard — sign in to moderate the platform
        </p>

        <label style={{ fontSize: 12, fontWeight: 600, color: '#0F172A' }}>Email</label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="admin@quickfix.com"
          style={inputStyle}
        />
        <label style={{ fontSize: 12, fontWeight: 600, color: '#0F172A' }}>Password</label>
        <input
          type="password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="••••••••"
          style={inputStyle}
        />

        {error && (
          <p style={{ color: '#E53935', fontSize: 12, marginTop: 12 }}>{error}</p>
        )}

        <button
          type="submit"
          disabled={loading}
          style={{
            width: '100%',
            marginTop: 20,
            padding: '14px 0',
            borderRadius: 16,
            border: 'none',
            background: ctaOrange,
            color: '#fff',
            fontSize: 15,
            fontWeight: 700,
            cursor: loading ? 'not-allowed' : 'pointer',
            opacity: loading ? 0.7 : 1,
          }}
        >
          {loading ? 'Signing in…' : 'Login'}
        </button>
      </form>
    </div>
  )
}

const inputStyle: React.CSSProperties = {
  width: '100%',
  boxSizing: 'border-box',
  margin: '6px 0 16px',
  padding: '12px 14px',
  borderRadius: 14,
  border: '1px solid #E2E8F0',
  fontSize: 14,
  outline: 'none',
}