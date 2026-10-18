import { useEffect, useId, useLayoutEffect, useRef, type ReactNode } from 'react'

let scrollLocks = 0
let previousOverflow = ''

interface ModalProps {
  title: string
  onClose: () => void
  children: ReactNode
}

export default function Modal({ title, onClose, children }: ModalProps) {
  const dialogRef = useRef<HTMLDivElement>(null)
  const closeRef = useRef(onClose)
  const titleId = useId()
  useLayoutEffect(() => { closeRef.current = onClose }, [onClose])
  useEffect(() => {
    const dialog = dialogRef.current
    if (!dialog) return
    const previousFocus = document.activeElement
    if (scrollLocks++ === 0) previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const focusable = () => Array.from(dialog.querySelectorAll<HTMLElement>(
      'a[href], button:not([disabled]), input:not([disabled]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
    )).filter((element) => element.tabIndex >= 0 && element.getClientRects().length > 0)
    const topmost = () => Array.from(document.querySelectorAll('[aria-modal="true"]')).at(-1) === dialog
    ;(focusable()[0] ?? dialog).focus()
    const keydown = (event: KeyboardEvent) => {
      if (!topmost()) return
      if (event.key === 'Escape') { event.preventDefault(); closeRef.current(); return }
      if (event.key !== 'Tab') return
      const elements = focusable()
      const first = elements[0]
      const last = elements.at(-1)
      if (!first || !last) { event.preventDefault(); dialog.focus(); return }
      const active = document.activeElement
      if (!dialog.contains(active)) { event.preventDefault(); (event.shiftKey ? last : first).focus() }
      else if (event.shiftKey && active === first) { event.preventDefault(); last.focus() }
      else if (!event.shiftKey && active === last) { event.preventDefault(); first.focus() }
    }
    document.addEventListener('keydown', keydown, true)
    return () => {
      document.removeEventListener('keydown', keydown, true)
      if (--scrollLocks === 0) document.body.style.overflow = previousOverflow
      if (previousFocus instanceof HTMLElement && previousFocus.isConnected) previousFocus.focus()
    }
  }, [])
  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(15, 23, 42, 0.45)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 50,
        padding: 20,
      }}
      onClick={onClose}
    >
      <div
        ref={dialogRef}
        role="dialog"
        tabIndex={-1}
        aria-modal="true"
        aria-labelledby={titleId}
        style={{
          maxHeight: '85vh',
          overflowY: 'auto',
          background: '#fff',
          borderRadius: 16,
          width: '100%',
          maxWidth: 460,
          padding: 24,
          boxShadow: '0 20px 40px rgba(15, 23, 42, 0.25)',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            marginBottom: 16,
          }}
        >
          <h3 id={titleId} style={{ margin: 0, fontSize: 16, fontWeight: 800, color: '#0F172A' }}>{title}</h3>
          <button
            onClick={onClose}
            aria-label="Close"
            style={{
              background: '#F1F5F9',
              border: 'none',
              borderRadius: 8,
              width: 44,
              height: 44,
              cursor: 'pointer',
              color: '#64748B',
              fontSize: 14,
              lineHeight: 1,
            }}
          >
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
  )
}
