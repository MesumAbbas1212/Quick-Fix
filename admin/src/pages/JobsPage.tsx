import { useEffect, useState } from 'react'
import DataTable from '../components/DataTable'
import { deleteJob, subscribeJobs, type JobRow } from '../api/jobs'

const dangerRed = '#E53935'

const statusColors: Record<string, string> = {
  open: '#004F9F',
  assigned: '#B26A00',
  inProgress: '#F36C00',
  completed: '#10B981',
  cancelled: '#E53935',
}

export default function JobsPage() {
  const [jobs, setJobs] = useState<JobRow[]>([])

  useEffect(() => subscribeJobs(setJobs), [])

  return (
    <div>
      <h2 style={{ color: '#0F172A', fontSize: 20, fontWeight: 800, margin: '0 0 16px' }}>Jobs</h2>
      <DataTable
        rows={jobs}
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
            onClick={() => deleteJob(r.id)}
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
    </div>
  )
}