interface StatCardProps {
  label: string
  value: number | string
  color?: string
}

export default function StatCard({ label, value, color = '#F36C00' }: StatCardProps) {
  return (
    <div
      style={{
        flex: 1,
        minWidth: 180,
        background: '#fff',
        border: '1px solid #E2E8F0',
        borderRadius: 16,
        padding: 20,
      }}
    >
      <div style={{ fontSize: 12, color: '#64748B', fontWeight: 600 }}>{label}</div>
      <div style={{ fontSize: 28, fontWeight: 800, color, marginTop: 6 }}>{value}</div>
    </div>
  )
}
