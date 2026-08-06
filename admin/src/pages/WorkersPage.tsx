import { useEffect, useState } from 'react'
import DataTable from '../components/DataTable'
import {
  approveWorker,
  blockWorker,
  subscribeWorkers,
  type WorkerRow,
} from '../api/workers'

const dangerRed = '#E53935'
const green = '#10B981'
const brandBlue = '#004F9F'

export default function WorkersPage() {
  const [workers, setWorkers] = useState<WorkerRow[]>([])

  useEffect(() => subscribeWorkers(setWorkers), [])

  return (
    <div>
      <h2 style={{ color: '#0F172A', fontSize: 20, fontWeight: 800, margin: '0 0 16px' }}>
        Workers
      </h2>
      <DataTable
        rows={workers}
        columns={[
          { key: 'name', header: 'Name', render: (r) => r.name },
          { key: 'professions', header: 'Skills', render: (r) => r.professions.join(', ') || '—' },
          { key: 'rating', header: 'Rating', render: (r) => `${r.rating.toFixed(1)} ★` },
          { key: 'completed', header: 'Completed Jobs', render: (r) => r.completedJobs },
          {
            key: 'approved',
            header: 'Approved',
            render: (r) => (
              <span style={{ color: r.approved ? green : brandBlue, fontWeight: 600 }}>
                {r.approved ? 'Approved' : 'Pending'}
              </span>
            ),
          },
        ]}
        actions={(r) => (
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
            <button
              onClick={() => approveWorker(r.id, !r.approved)}
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
              {r.approved ? 'Unapprove' : 'Approve'}
            </button>
            <button
              onClick={() => blockWorker(r.id, !r.blocked)}
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
              {r.blocked ? 'Unblock' : 'Block'}
            </button>
          </div>
        )}
      />
    </div>
  )
}