export interface Column<T> {
  key: string
  header: string
  render: (row: T) => React.ReactNode
}

interface DataTableProps<T> {
  columns: Column<T>[]
  rows: T[]
  actions?: (row: T) => React.ReactNode
}

export default function DataTable<T>({ columns, rows, actions }: DataTableProps<T>) {
  const pageRows = rows.slice(0, 50)

  if (rows.length === 0) {
    return (
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
        No records found.
      </div>
    )
  }

  return (
    <div style={{ background: '#fff', border: '1px solid #E2E8F0', borderRadius: 16, overflow: 'hidden' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
        <thead>
          <tr style={{ background: '#F8FAFC' }}>
            {columns.map((c) => (
              <th
                key={c.key}
                style={{
                  textAlign: 'left',
                  padding: '12px 16px',
                  color: '#64748B',
                  fontSize: 11,
                  fontWeight: 700,
                  textTransform: 'uppercase',
                  letterSpacing: 0.5,
                }}
              >
                {c.header}
              </th>
            ))}
            {actions && (
              <th
                style={{
                  textAlign: 'right',
                  padding: '12px 16px',
                  color: '#64748B',
                  fontSize: 11,
                  fontWeight: 700,
                  textTransform: 'uppercase',
                  letterSpacing: 0.5,
                }}
              >
                Actions
              </th>
            )}
          </tr>
        </thead>
        <tbody>
          {pageRows.map((row, i) => (
            <tr key={i} style={{ borderTop: '1px solid #E2E8F0' }}>
              {columns.map((c) => (
                <td key={c.key} style={{ padding: '12px 16px', color: '#0F172A' }}>
                  {c.render(row)}
                </td>
              ))}
              {actions && (
                <td style={{ padding: '12px 16px', textAlign: 'right' }}>{actions(row)}</td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
      {rows.length > 50 && (
        <div style={{ padding: '10px 16px', borderTop: '1px solid #E2E8F0', color: '#64748B', fontSize: 12 }}>
          Showing 50 of {rows.length} records
        </div>
      )}
    </div>
  )
}
