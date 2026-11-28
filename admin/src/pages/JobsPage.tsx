import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import DataTable from '../components/DataTable'
import Modal from '../components/Modal'
import {
  errorTextStyle,
  fieldGap,
  inputStyle,
  labelStyle,
  primaryButtonStyle,
  secondaryButtonStyle,
  toastStyle,
} from '../components/fieldStyles'
import { deleteJobWithReason, subscribeJobs, type JobRow } from '../api/jobs'

const dangerRed = '#E53935'

const statusColors: Record<string, string> = {
  open: '#004F9F',
  assigned: '#B26A00',
  inProgress: '#F36C00',
  completed: '#10B981',
  cancelled: '#E53935',
}

/** Default reasons offered when deleting, matching the mobile admin screen. */
const REASONS = ['Test data', 'Duplicate', 'Spam', 'Requested by user']
const CUSTOM_REASON = 'Other (type a reason)'

export default function JobsPage() {
  const [jobs, setJobs] = useState<JobRow[]>([])
  const navigate = useNavigate()

  const [deleting, setDeleting] = useState<JobRow | null>(null)
  const [reason, setReason] = useState(REASONS[0])
  const [custom, setCustom] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [toast, setToast] = useState<string | null>(null)

  useEffect(() => subscribeJobs(setJobs), [])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 4000)
    return () => clearTimeout(timer)
  }, [toast])

  const close = () => {
    if (busy) return
    setDeleting(null)
    setReason(REASONS[0])
    setCustom('')
    setError(null)
  }

  const chosenReason = (reason === CUSTOM_REASON ? custom : reason).trim()

  const confirmDelete = async () => {
    if (!deleting || !chosenReason || busy) return
    setBusy(true)
    setError(null)
    try {
      const counts = await deleteJobWithReason(deleting.id, chosenReason)
      setToast(
        `Job deleted. Also removed ${counts.jobRequests} ` +
          `${counts.jobRequests === 1 ? 'application' : 'applications'} and ` +
          `${counts.notifications} ${counts.notifications === 1 ? 'notification' : 'notifications'}.`,
      )
      setDeleting(null)
      setReason(REASONS[0])
      setCustom('')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div>
      <h2 style={{ color: '#0F172A', fontSize: 20, fontWeight: 800, margin: '0 0 16px' }}>Jobs</h2>
      <DataTable
        rows={jobs}
        onRowClick={(r) => navigate(`/jobs/${r.id}`)}
        columns={[
          { key: 'title', header: 'Title', render: (r) => r.title },
          {
            key: 'category',
            header: 'Category',
            render: (r) => (
              <span style={{ textTransform: 'capitalize' }}>
                {r.category.replace(/_/g, ' ')}
              </span>
            ),
          },
          {
            key: 'status',
            header: 'Status',
            render: (r) => (
              <span
                style={{
                  color: statusColors[r.status] ?? '#64748B',
                  fontWeight: 600,
                  textTransform: 'capitalize',
                }}
              >
                {r.status.replace(/([A-Z])/g, ' $1')}
              </span>
            ),
          },
          { key: 'created', header: 'Created', render: (r) => r.createdAt || '—' },
        ]}
        actions={(r) => (
          <button
            onClick={() => {
              setDeleting(r)
              setReason(REASONS[0])
              setCustom('')
              setError(null)
            }}
            style={{
              background: '#FFF1F2',
              color: dangerRed,
              border: '1px solid #FECDD3',
              borderRadius: 10,
              padding: '6px 14px',
              fontSize: 12,
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            Delete
          </button>
        )}
      />

      {deleting && (
        <Modal title={`Delete “${deleting.title || 'Untitled job'}”?`} onClose={close}>
          <p style={{ margin: '0 0 6px', fontSize: 13, fontWeight: 600, color: '#0F172A' }}>
            This cannot be undone. Deleting removes:
          </p>
          <ul style={{ margin: '0 0 10px', paddingLeft: 18, fontSize: 13, color: '#0F172A' }}>
            <li>the job and its photos, for both the client and the worker;</li>
            <li>its applications and notifications.</li>
          </ul>
          <p style={{ margin: '0 0 14px', fontSize: 12, color: '#64748B' }}>
            Payment and review records are kept: they are the client and worker financial and
            rating history.
          </p>

          <div style={fieldGap}>
            <label style={labelStyle} htmlFor="delete-reason">Reason (required)</label>
            <select
              id="delete-reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              style={inputStyle}
            >
              {REASONS.map((option) => (
                <option key={option} value={option}>{option}</option>
              ))}
              <option value={CUSTOM_REASON}>{CUSTOM_REASON}</option>
            </select>
          </div>

          {reason === CUSTOM_REASON && (
            <div style={fieldGap}>
              <label style={labelStyle} htmlFor="delete-custom-reason">Custom reason</label>
              <input
                id="delete-custom-reason"
                value={custom}
                maxLength={200}
                onChange={(e) => setCustom(e.target.value)}
                placeholder="Explain why this job must be deleted"
                style={inputStyle}
              />
            </div>
          )}

          {error && <div style={{ ...errorTextStyle, marginBottom: 12 }}>{error}</div>}

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
            <button onClick={close} disabled={busy} style={secondaryButtonStyle}>
              Keep job
            </button>
            <button
              onClick={confirmDelete}
              disabled={busy || !chosenReason}
              style={{
                ...primaryButtonStyle,
                background: dangerRed,
                opacity: busy || !chosenReason ? 0.5 : 1,
                cursor: busy || !chosenReason ? 'not-allowed' : 'pointer',
              }}
            >
              {busy ? 'Deleting…' : 'Delete permanently'}
            </button>
          </div>
        </Modal>
      )}

      {toast && <div style={toastStyle(false)}>{toast}</div>}
    </div>
  )
}
