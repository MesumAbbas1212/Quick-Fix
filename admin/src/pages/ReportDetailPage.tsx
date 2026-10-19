import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  errorTextStyle,
  inputStyle,
  labelStyle,
  primaryButtonStyle,
  secondaryButtonStyle,
  toastStyle,
  fieldGap,
} from '../components/fieldStyles'
import { auth } from '../config/firebase'
import {
  getReportDetail,
  resolveReport,
  type PersonSummary,
  type ReportDetail,
} from '../api/reports'

const brandBlue = '#004F9F'
const green = '#10B981'

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div
      style={{
        background: '#fff',
        border: '1px solid #E2E8F0',
        borderRadius: 16,
        padding: 20,
        marginBottom: 16,
      }}
    >
      <h3 style={{ margin: '0 0 14px', fontSize: 14, fontWeight: 800, color: '#0F172A' }}>
        {title}
      </h3>
      {children}
    </div>
  )
}

function InfoRow({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', gap: 12, padding: '6px 0', fontSize: 13 }}>
      <span style={{ width: 130, color: '#64748B', fontWeight: 600, flexShrink: 0 }}>{label}</span>
      <span style={{ color: '#0F172A', wordBreak: 'break-word' }}>{value || '—'}</span>
    </div>
  )
}

function PersonCard({ title, person }: { title: string; person: PersonSummary | null }) {
  return (
    <Card title={title}>
      {!person ? (
        <div style={{ color: '#64748B', fontSize: 13 }}>Account not found.</div>
      ) : (
        <>
          <InfoRow label="Name" value={person.name} />
          <InfoRow label="Email" value={person.email} />
          <InfoRow label="Phone" value={person.phone} />
          <InfoRow label="Role" value={person.role} />
          <InfoRow label="Joined" value={person.joined} />
        </>
      )}
    </Card>
  )
}

export default function ReportDetailPage() {
  const { reportId } = useParams<{ reportId: string }>()
  const [detail, setDetail] = useState<ReportDetail | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [note, setNote] = useState('')
  const [noteError, setNoteError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [toast, setToast] = useState<{ text: string; error?: boolean } | null>(null)

  useEffect(() => {
    if (!reportId) return
    let cancelled = false
    setLoading(true)
    getReportDetail(reportId)
      .then((d) => {
        if (!cancelled) setDetail(d)
      })
      .catch((e) => {
        if (!cancelled) setError(e instanceof Error ? e.message : 'Failed to load report.')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [reportId])

  useEffect(() => {
    if (!toast) return
    const t = setTimeout(() => setToast(null), 3000)
    return () => clearTimeout(t)
  }, [toast])

  async function decide(status: 'resolved' | 'dismissed') {
    if (!detail) return
    if (!note.trim()) {
      setNoteError('A note is required — every moderation action must be logged.')
      return
    }
    setSaving(true)
    try {
      await resolveReport(detail.report.id, status, note, auth.currentUser?.uid ?? 'admin')
      setDetail({
        ...detail,
        report: {
          ...detail.report,
          status,
          resolutionNote: note.trim(),
          resolvedAt: new Date().toLocaleDateString(),
          resolvedBy: auth.currentUser?.uid ?? 'admin',
        },
      })
      setToast({
        text: status === 'resolved' ? 'Report resolved.' : 'Report dismissed.',
      })
    } catch (e) {
      setToast({ text: 'Could not update. ' + (e instanceof Error ? e.message : ''), error: true })
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div style={{ color: '#64748B', fontSize: 13, padding: 40, textAlign: 'center' }}>
        Loading report…
      </div>
    )
  }

  if (error) {
    return (
      <div style={{ padding: 40, textAlign: 'center' }}>
        <div style={{ ...errorTextStyle, marginBottom: 16 }}>{error}</div>
        <Link to="/reports" style={{ color: brandBlue, fontSize: 13, fontWeight: 600 }}>
          ← Back to reports
        </Link>
      </div>
    )
  }

  if (!detail) {
    return (
      <div style={{ padding: 40, textAlign: 'center' }}>
        <div style={{ color: '#0F172A', fontSize: 16, fontWeight: 800, marginBottom: 8 }}>
          Report not found
        </div>
        <div style={{ color: '#64748B', fontSize: 13, marginBottom: 16 }}>
          It may have been removed.
        </div>
        <Link to="/reports" style={{ color: brandBlue, fontSize: 13, fontWeight: 600 }}>
          ← Back to reports
        </Link>
      </div>
    )
  }

  const r = detail.report
  const open = r.status === 'open'

  return (
    <div style={{ maxWidth: 860 }}>
      <Link to="/reports" style={{ color: brandBlue, fontSize: 13, fontWeight: 600 }}>
        ← Back to reports
      </Link>

      <Card title={`Report — ${r.reason}`}>
        <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
          <span
            style={{
              background: open ? '#EFF6FF' : r.status === 'resolved' ? '#F0FDF4' : '#F1F5F9',
              color: open ? brandBlue : r.status === 'resolved' ? green : '#64748B',
              borderRadius: 8,
              padding: '3px 10px',
              fontSize: 11,
              fontWeight: 700,
              textTransform: 'capitalize',
            }}
          >
            {r.status}
          </span>
          <span style={{ color: '#64748B', fontSize: 12 }}>Filed {r.createdAt}</span>
        </div>
        {r.disputeId && <p style={{ fontSize: 13 }}>Linked completed-job dispute. Resolving this report also updates its matching case. Evidence photos are device-local; use an approved separate channel, not this page, to review images. No automatic refund is processed.</p>}
        {r.details && (
          <p style={{ margin: '0 0 12px', fontSize: 13, color: '#0F172A', lineHeight: 1.5 }}>
            {r.details}
          </p>
        )}
        {detail.job && (
          <InfoRow
            label="Job context"
            value={
              <Link to={`/jobs/${detail.job.id}`} style={{ color: brandBlue, fontWeight: 600 }}>
                {detail.job.title} ({detail.job.status})
              </Link>
            }
          />
        )}
        {!open && (
          <>
            <InfoRow label="Decision" value={r.status} />
            <InfoRow label="Note" value={r.resolutionNote} />
            <InfoRow label="By" value={r.resolvedBy} />
            <InfoRow label="At" value={r.resolvedAt} />
          </>
        )}
      </Card>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 0 }}>
        <PersonCard title="Reporter" person={detail.reporter} />
        <div>
          <PersonCard title="Reported account" person={detail.reported} />
          <Card title="Reported account — worker stats">
            <InfoRow label="Rating" value={`${(detail.reported?.rating ?? 0).toFixed(1)} ★`} />
            <InfoRow label="Completed jobs" value={detail.reported?.completedJobs ?? 0} />
            <InfoRow label="Prior reports" value={detail.priorReportCount} />
          </Card>
        </div>
      </div>

      <Card title="Evidence — recent reviews of the reported worker">
        {detail.recentReviews.length === 0 ? (
          <div style={{ color: '#64748B', fontSize: 13 }}>
            No reviews found for this account.
          </div>
        ) : (
          detail.recentReviews.map((rev) => (
            <div
              key={rev.id}
              style={{
                borderTop: '1px solid #E2E8F0',
                padding: '10px 0',
                fontSize: 13,
                display: 'flex',
                gap: 12,
              }}
            >
              <span style={{ fontWeight: 700, color: '#F59E0B', flexShrink: 0 }}>
                {rev.rating.toFixed(1)} ★
              </span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div dir="auto" style={{ color: '#0F172A' }}>
                  {rev.text || '(no text)'}
                </div>
                <div style={{ color: '#94A3B8', fontSize: 11, marginTop: 2 }}>
                  {rev.lang} · {rev.date}
                </div>
              </div>
            </div>
          ))
        )}
      </Card>

      {open && (
        <Card title="Decision">
          <div style={fieldGap}>
            <label style={labelStyle}>Note (required — logged with the decision)</label>
            <textarea
              style={{ ...inputStyle, minHeight: 72, resize: 'vertical' }}
              value={note}
              onChange={(e) => {
                setNote(e.target.value)
                if (noteError) setNoteError(null)
              }}
              placeholder="What did you find, and why is this the right outcome?"
            />
            {noteError && <div style={errorTextStyle}>{noteError}</div>}
          </div>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
            <button
              onClick={() => decide('dismissed')}
              disabled={saving}
              style={{
                ...secondaryButtonStyle,
                color: '#64748B',
                opacity: saving ? 0.6 : 1,
              }}
            >
              Dismiss
            </button>
            <button
              onClick={() => decide('resolved')}
              disabled={saving}
              style={{ ...primaryButtonStyle, background: green, opacity: saving ? 0.6 : 1 }}
            >
              {saving ? 'Saving…' : 'Resolve report'}
            </button>
          </div>
        </Card>
      )}

      {toast && <div style={toastStyle(Boolean(toast.error))}>{toast.text}</div>}
    </div>
  )
}
