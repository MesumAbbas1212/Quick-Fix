import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import DataTable from '../components/DataTable'
import Modal from '../components/Modal'
import { approveWorker, blockWorker, getWorkerVerification, reviewWorkerVerification, subscribeWorkers,
  type VerificationReview, type VerificationStatus, type WorkerRow } from '../api/workers'

const brandBlue = '#0D47A1'
const labels: Record<VerificationStatus, string> = { notStarted: 'Not started', pending: 'Pending', verified: 'Verified (manual)', rejected: 'Rejected' }
const button = { background: '#fff', color: brandBlue, border: '1px solid #E2E8F0', borderRadius: 10, padding: '8px 12px', fontSize: 12, fontWeight: 600, cursor: 'pointer' } as const

function VerificationModal({ worker, onClose }: { worker: WorkerRow; onClose: () => void }) {
  const [data, setData] = useState<VerificationReview | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [revision, setRevision] = useState(0)
  const [note, setNote] = useState('')
  const [next, setNext] = useState<'verified' | 'rejected'>(worker.verificationStatus === 'verified' ? 'rejected' : 'verified')
  const [confirmed, setConfirmed] = useState(false)
  useEffect(() => {
    let cancelled = false
    setLoading(true); setError('')
    getWorkerVerification(worker.id).then((value) => {
      if (cancelled) return
      setData(value); setNote(value?.note ?? ''); setLoading(false)
    }).catch(() => { if (!cancelled) { setError('Could not load this private request. Retry.'); setLoading(false) } })
    return () => { cancelled = true }
  }, [worker.id, revision])
  async function save() {
    if (busy || !data) return
    setBusy(true); setError('')
    try {
      await reviewWorkerVerification(worker.id, next, note, confirmed)
      onClose()
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Could not confirm review. Refresh before retrying.')
    } finally { setBusy(false) }
  }
  return <Modal title={`Identity review — ${worker.name}`} onClose={busy ? () => {} : onClose}>
    <p style={{ color: '#64748B', fontSize: 13 }}>Demo limitation: photos stay on the worker’s device. These file references are private, not downloadable evidence. Do not approve based on their presence. Perform a separate approved secure or in-person identity check first.</p>
    {loading ? <p>Loading private request…</p> : data ? <>
      <p>Status: <strong>{labels[data.status]}</strong></p>
      <p style={{ fontSize: 13 }}>Local capture references: CNIC front {data.hasFront ? 'recorded' : 'missing'}, back {data.hasBack ? 'recorded' : 'missing'}, selfie {data.hasSelfie ? 'recorded' : 'missing'}.</p>
      <label style={{ display: 'block', fontSize: 13 }}>Decision
        <select aria-label="Verification decision" value={next} disabled={busy} onChange={(event) => setNext(event.target.value as 'verified' | 'rejected')} style={{ display: 'block', padding: 10, width: '100%', margin: '6px 0 12px' }}>
          <option value="verified">Mark verified after manual check</option><option value="rejected">Reject / revoke with reason</option>
        </select>
      </label>
      <label style={{ display: 'block', fontSize: 13 }}>Private note (required for rejection)
        <textarea aria-label="Private verification note" value={note} maxLength={1000} disabled={busy} onChange={(event) => setNote(event.target.value)} style={{ display: 'block', width: '100%', minHeight: 80, margin: '6px 0 12px', boxSizing: 'border-box' }} />
      </label>
      {next === 'verified' && <label style={{ display: 'flex', gap: 8, fontSize: 13, marginBottom: 16 }}>
        <input type="checkbox" checked={confirmed} disabled={busy} onChange={(event) => setConfirmed(event.target.checked)} />
        I personally completed a separate approved secure or in-person identity check. No automatic/background-check claim is implied.
      </label>}
      <button style={button} disabled={busy || (next === 'verified' && (!confirmed || !data.consent || !data.hasFront || !data.hasBack || !data.hasSelfie)) || (next === 'rejected' && !note.trim())} onClick={save}>{busy ? 'Saving…' : 'Confirm decision'}</button>
    </> : <p>No submitted verification. Ask the worker to submit first.</p>}
    {error && <div role="alert" style={{ color: '#E53935', fontSize: 13, marginTop: 12 }}>{error}<br /><button style={button} disabled={busy || loading} onClick={() => setRevision((value) => value + 1)}>Reload request</button></div>}
  </Modal>
}

export default function WorkersPage() {
  const [workers, setWorkers] = useState<WorkerRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState<string | null>(null)
  const [reviewing, setReviewing] = useState<WorkerRow | null>(null)
  const [revision, setRevision] = useState(0)
  const navigate = useNavigate()
  useEffect(() => {
    setLoading(true); setError('')
    const timeout = setTimeout(() => { setLoading(false); setError('Worker loading timed out. Retry the subscription.') }, 12000)
    const unsubscribe = subscribeWorkers((values) => { clearTimeout(timeout); setWorkers(values); setLoading(false); setError('') }, () => {
      clearTimeout(timeout); setLoading(false); setError('Could not load workers. Check access and retry.')
    })
    return () => { clearTimeout(timeout); unsubscribe() }
  }, [revision])
  async function run(worker: WorkerRow, action: () => Promise<unknown>) {
    if (busy) return
    setBusy(worker.id); setError('')
    try { await action() } catch { setError('Could not confirm the worker update. Refresh before retrying.') } finally { setBusy(null) }
  }
  return <div>
    <h2 style={{ color: '#0F172A', fontSize: 20, fontWeight: 800, margin: '0 0 16px' }}>Workers</h2>
    {error && <div role="alert" style={{ color: '#E53935', marginBottom: 12 }}>{error} <button style={button} onClick={() => setRevision((value) => value + 1)}>Retry</button></div>}
    {loading && <p>Loading workers…</p>}
    {!loading && workers.length === 0 && <p>No workers yet. <button style={button} onClick={() => setRevision((value) => value + 1)}>Refresh</button></p>}
    <DataTable rows={workers} onRowClick={(row) => navigate(`/workers/${row.id}`)} columns={[
      { key: 'name', header: 'Name', render: (row) => row.name },
      { key: 'professions', header: 'Skills', render: (row) => row.professions.join(', ') || '—' },
      { key: 'rating', header: 'Rating', render: (row) => `${row.rating.toFixed(1)} / 5` },
      { key: 'completed', header: 'Completed jobs', render: (row) => row.completedJobs },
      { key: 'approved', header: 'Approved', render: (row) => row.approved ? 'Approved' : 'Pending' },
      { key: 'verified', header: 'Verified', render: (row) => <span style={{ color: row.verificationStatus === 'verified' ? '#047857' : '#64748B', fontWeight: 600 }}>{labels[row.verificationStatus]}</span> },
    ]} actions={(row) => <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'flex-end' }}>
      <button style={button} disabled={busy !== null} onClick={() => run(row, () => approveWorker(row.id, !row.approved))}>{row.approved ? 'Unapprove' : 'Approve'}</button>
      <button style={{ ...button, color: '#E53935' }} disabled={busy !== null} onClick={() => run(row, () => blockWorker(row.id, !row.blocked))}>{row.blocked ? 'Unblock' : 'Block'}</button>
      <button style={button} disabled={busy !== null || !['pending', 'verified'].includes(row.verificationStatus)} onClick={() => setReviewing(row)}>{row.verificationStatus === 'verified' ? 'Review / revoke' : 'Review identity'}</button>
    </div>} />
    {reviewing && <VerificationModal worker={reviewing} onClose={() => setReviewing(null)} />}
  </div>
}
