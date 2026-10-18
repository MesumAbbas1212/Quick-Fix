import type { CSSProperties } from 'react'

/** Shared field/button styles for admin modals and forms. */

export const labelStyle: CSSProperties = {
  display: 'block',
  fontSize: 12,
  fontWeight: 700,
  color: '#334155',
  marginBottom: 6,
}

export const inputStyle: CSSProperties = {
  width: '100%',
  boxSizing: 'border-box',
  border: '1px solid #CBD5E1',
  borderRadius: 10,
  padding: '10px 12px',
  fontSize: 13,
  color: '#0F172A',
  outline: 'none',
}

export const fieldGap: CSSProperties = { marginBottom: 14 }

export const errorTextStyle: CSSProperties = {
  color: '#E53935',
  fontSize: 12,
  fontWeight: 600,
  marginTop: 4,
}

export const primaryButtonStyle: CSSProperties = {
  background: '#004F9F',
  color: '#fff',
  border: 'none',
  borderRadius: 10,
  padding: '10px 18px',
  fontSize: 13,
  fontWeight: 700,
  cursor: 'pointer',
}

export const secondaryButtonStyle: CSSProperties = {
  background: '#F1F5F9',
  color: '#334155',
  border: '1px solid #CBD5E1',
  borderRadius: 10,
  padding: '10px 18px',
  fontSize: 13,
  fontWeight: 600,
  cursor: 'pointer',
}

export const toastStyle = (error: boolean): CSSProperties => ({
  position: 'fixed',
  bottom: 24,
  left: '50%',
  transform: 'translateX(-50%)',
  background: error ? '#FEF2F2' : '#F0FDF4',
  color: error ? '#E53935' : '#10B981',
  border: `1px solid ${error ? '#FECDD3' : '#A7F3D0'}`,
  borderRadius: 12,
  padding: '10px 20px',
  fontSize: 13,
  fontWeight: 600,
  zIndex: 100,
})
