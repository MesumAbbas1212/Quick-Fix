import { useEffect, useState } from 'react'
import DataTable from '../components/DataTable'
import { resolveReport, subscribeReports, type ReportRow } from '../api/reports'

const green = '#10B981'
const brandBlue = '#004F9F'

export default function ReportsPage() {
  const [reports, setReports] = useState<ReportRow[]>([])

  useEffect(() => subscribeReports(setReports), [])

  return (
    <div>
      <h2 style={{ color: '#0F172A', fontSize: 20, fontWeight: 800, margin: '0 0 16px' }}>
        Reports
      </h2>
      <DataTable
        rows={reports}
        columns={[
          { key: 'by', header: 'Reported By', render: (r) => r.reportedBy },
          { key: 'user', header: 'Reported User', render: (r) => r.reportedUser },
          { key: 'reason', header: 'Reason', render: (r) => r.reason },
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
        actions={(r) => (
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
            {r.status === 'open' && (
              <>
                <button
                  onClick={() => resolveReport(r.id, 'resolved')}
                  style={{
                    background: '#F0FDF4',
                    color: green,
                    border: '1px solid #A7F3D0',
                    borderRadius: 10,
                    padding: '6px 14px',
                    fontSize: 12,
                    fontWeight: 600,
                    cursor: 'pointer',
                  }}
                >
                  Resolve
                </button>
                <button
                  onClick={() => resolveReport(r.id, 'dismissed')}
                  style={{
                    background: '#F1F5F9',
                    color: '#64748B',
                    border: '1px solid #CBD5E1',
                    borderRadius: 10,
                    padding: '6px 14px',
                    fontSize: 12,
                    fontWeight: 600,
                    cursor: 'pointer',
                  }}
                >
                  Dismiss
                </button>
              </>
            )}
          </div>
        )}
      />
    </div>
  )
}