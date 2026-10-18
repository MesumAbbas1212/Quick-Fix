import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import DataTable from '../components/DataTable'
import { subscribeReports, type ReportRow } from '../api/reports'

const green = '#10B981'
const brandBlue = '#004F9F'

export default function ReportsPage() {
  const [reports, setReports] = useState<ReportRow[]>([])
  const [loaded, setLoaded] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const navigate = useNavigate()

  useEffect(() => {
    const unsub = subscribeReports(
      (rows) => {
        setReports(rows)
        setLoaded(true)
      },
      (message) => setError(message),
    )
    return unsub
  }, [])

  const openCount = reports.filter((r) => r.status === 'open').length

  return (
    <div>
      <h2 style={{ color: '#0F172A', fontSize: 20, fontWeight: 800, margin: '0 0 16px' }}>
        Reports{' '}
        <span style={{ color: '#64748B', fontWeight: 600, fontSize: 13 }}>
          {openCount} open · {reports.length} total
        </span>
      </h2>

      {error && (
        <div style={{ color: '#E53935', fontSize: 12, fontWeight: 600, marginBottom: 12 }}>
          Could not load reports: {error}
        </div>
      )}
      {!loaded && !error ? (
        <div
          style={{
            background: '#fff',
            border: '1px solid #E2E8F0',
            borderRadius: 16,
            padding: 32,
            textAlign: 'center',
            color: '#64748B',
            fontSize: 13,
          }}
        >
          Loading reports…
        </div>
      ) : (
        <DataTable
          rows={reports}
          onRowClick={(r) => navigate(`/reports/${r.id}`)}
          columns={[
            { key: 'by', header: 'Reporter', render: (r) => r.reporterId },
            { key: 'user', header: 'Reported', render: (r) => r.reportedId },
            { key: 'reason', header: 'Reason', render: (r) => r.reason },
            {
              key: 'details',
              header: 'Details',
              render: (r) =>
                r.details ? (
                  <span style={{ color: '#64748B' }}>{r.details.slice(0, 60)}</span>
                ) : (
                  '—'
                ),
            },
            {
              key: 'status',
              header: 'Status',
              render: (r) => (
                <span
                  style={{
                    color: r.status === 'open' ? brandBlue : r.status === 'resolved' ? green : '#64748B',
                    fontWeight: 600,
                    textTransform: 'capitalize',
                  }}
                >
                  {r.status}
                </span>
              ),
            },
            { key: 'created', header: 'Date', render: (r) => r.createdAt || '—' },
          ]}
        />
      )}
    </div>
  )
}
