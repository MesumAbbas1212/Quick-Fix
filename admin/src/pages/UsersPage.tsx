import { useEffect, useState } from 'react'
import DataTable from '../components/DataTable'
import { blockUser, subscribeUsers, type UserRow } from '../api/users'

const dangerRed = '#E53935'
const green = '#10B981'

export default function UsersPage() {
  const [users, setUsers] = useState<UserRow[]>([])

  useEffect(() => subscribeUsers(setUsers), [])

  return (
    <div>
      <h2 style={{ color: '#0F172A', fontSize: 20, fontWeight: 800, margin: '0 0 16px' }}>Users</h2>
      <DataTable
        rows={users}
        columns={[
          { key: 'name', header: 'Name', render: (r) => r.name },
          { key: 'email', header: 'Email', render: (r) => r.email },
          { key: 'phone', header: 'Phone', render: (r) => r.phone },
          {
            key: 'role',
            header: 'Role',
            render: (r) => (
              <span
                style={{
                  background: r.role === 'worker' ? '#FFF7E6' : '#E0F2FE',
                  color: r.role === 'worker' ? '#B26A00' : '#004F9F',
                  padding: '2px 10px',
                  borderRadius: 10,
                  fontSize: 11,
                  fontWeight: 700,
                  textTransform: 'capitalize',
                }}
              >
                {r.role}
              </span>
            ),
          },
          {
            key: 'status',
            header: 'Status',
            render: (r) => (
              <span style={{ color: r.blocked ? dangerRed : green, fontWeight: 600 }}>
                {r.blocked ? 'Blocked' : 'Active'}
              </span>
            ),
          },
        ]}
        actions={(r) => (
          <button
            onClick={() => blockUser(r.id, !r.blocked)}
            style={{
              background: r.blocked ? 'transparent' : '#FFF1F2',
              color: dangerRed,
              border: r.blocked ? 'none' : '1px solid #FECDD3',
              borderRadius: 10,
              padding: '6px 14px',
              fontSize: 12,
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            {r.blocked ? 'Unblock' : 'Block'}
          </button>
        )}
      />
    </div>
  )
}