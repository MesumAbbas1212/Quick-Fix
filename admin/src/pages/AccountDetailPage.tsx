import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import StatCard from '../components/StatCard'
import { errorTextStyle } from '../components/fieldStyles'
import { getAccountDetail, type AccountDetailData, type DetailItem } from '../api/accounts'

const brandBlue = '#004F9F'
const green = '#10B981'

const TABS = ['Activity', 'Reviews', 'Payments', 'Reports'] as const
type TabName = (typeof TABS)[number]

const TAB_COLORS: Record<TabName, string> = {
  Activity: brandBlue,
  Reviews: '#F59E0B',
  Payments: green,
  Reports: '#E53935',
}

function initials(name: string): string {
  return (
    name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((p) => p[0]?.toUpperCase() ?? '')
      .join('') || '?'
  )
}

function ItemList({ items, emptyLabel }: { items: DetailItem[]; emptyLabel: string }) {
  if (items.length === 0) {
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
        {emptyLabel}
      </div>
    )
  }
  return (
    <div style={{ background: '#fff', border: '1px solid #E2E8F0', borderRadius: 16, overflow: 'hidden' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
        <thead>
          <tr style={{ background: '#F8FAFC' }}>
            {['Title', 'Details', 'Date', 'Status / Amount'].map((h) => (
              <th
                key={h}
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
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.id} style={{ borderTop: '1px solid #E2E8F0' }}>
              <td style={{ padding: '12px 16px', color: '#0F172A', fontWeight: 600, maxWidth: 260 }}>
                <span dir="auto">{item.title}</span>
              </td>
              <td style={{ padding: '12px 16px', color: '#334155', maxWidth: 320 }}>
                <span dir="auto">{item.sub || '—'}</span>
              </td>
              <td style={{ padding: '12px 16px', color: '#64748B' }}>{item.date || '—'}</td>
              <td style={{ padding: '12px 16px' }}>
                {item.extra ? (
                  <span
                    style={{
                      color:
                        item.extra === 'completed'
                          ? green
                          : item.extra === 'cancelled'
                            ? '#E53935'
                            : brandBlue,
                      fontWeight: 600,
                      textTransform: 'capitalize',
                    }}
                  >
                    {item.extra}
                  </span>
                ) : (
                  '—'
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

interface AccountDetailPageProps {
  kind: 'user' | 'worker' | 'job'
  backTo: string
  backLabel: string
  kindLabel: string
}

/** Shared layout for the user / worker / job drill-down pages. */
export default function AccountDetailPage({
  kind,
  backTo,
  backLabel,
  kindLabel,
}: AccountDetailPageProps) {
  const { id } = useParams<{ id: string }>()
  const [data, setData] = useState<AccountDetailData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [tab, setTab] = useState<TabName>('Activity')

  useEffect(() => {
    if (!id) return
    let cancelled = false
    setLoading(true)
    getAccountDetail(kind, id)
      .then((d) => {
        if (!cancelled) setData(d)
      })
      .catch((e) => {
        if (!cancelled) setError(e instanceof Error ? e.message : 'Failed to load details.')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [kind, id])

  if (loading) {
    return (
      <div style={{ color: '#64748B', fontSize: 13, padding: 40, textAlign: 'center' }}>
        Loading {kindLabel}…
      </div>
    )
  }

  if (error) {
    return (
      <div style={{ padding: 40, textAlign: 'center' }}>
        <div style={{ ...errorTextStyle, marginBottom: 16 }}>{error}</div>
        <Link to={backTo} style={{ color: brandBlue, fontSize: 13, fontWeight: 600 }}>
          ← {backLabel}
        </Link>
      </div>
    )
  }

  if (!data) {
    return (
      <div style={{ padding: 40, textAlign: 'center' }}>
        <div style={{ color: '#0F172A', fontSize: 16, fontWeight: 800, marginBottom: 8 }}>
          {kindLabel} not found
        </div>
        <Link to={backTo} style={{ color: brandBlue, fontSize: 13, fontWeight: 600 }}>
          ← {backLabel}
        </Link>
      </div>
    )
  }

  const tabs: Record<TabName, { items: DetailItem[]; empty: string }> = {
    Activity: {
      items: data.tabs.activity,
      empty: kind === 'job' ? 'No applications for this job yet.' : 'No activity yet.',
    },
    Reviews: {
      items: data.tabs.reviews,
      empty: kind === 'worker' ? 'No reviews received yet.' : kind === 'job' ? 'No review for this job yet.' : 'No reviews written yet.',
    },
    Payments: {
      items: data.tabs.payments,
      empty: 'No payments recorded yet.',
    },
    Reports: {
      items: data.tabs.reports,
      empty: 'No reports involving this record.',
    },
  }

  return (
    <div style={{ maxWidth: 960 }}>
      <Link to={backTo} style={{ color: brandBlue, fontSize: 13, fontWeight: 600 }}>
        ← {backLabel}
      </Link>

      {/* Identity header */}
      <div
        style={{
          background: '#fff',
          border: '1px solid #E2E8F0',
          borderRadius: 16,
          padding: 20,
          marginTop: 12,
          marginBottom: 16,
          display: 'flex',
          gap: 16,
          alignItems: 'center',
        }}
      >
        {data.identity.avatarUrl ? (
          <img
            src={data.identity.avatarUrl}
            alt=""
            style={{ width: 52, height: 52, borderRadius: '50%', objectFit: 'cover' }}
          />
        ) : (
          <div
            style={{
              width: 52,
              height: 52,
              borderRadius: '50%',
              background: brandBlue,
              color: '#fff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontWeight: 800,
              fontSize: 18,
            }}
          >
            {initials(data.identity.name)}
          </div>
        )}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 17, fontWeight: 800, color: '#0F172A' }}>{data.identity.name}</div>
          <div style={{ fontSize: 12, color: '#64748B', marginTop: 2 }}>{data.identity.subtitle}</div>
          <div style={{ display: 'flex', gap: 6, marginTop: 8, flexWrap: 'wrap' }}>
            {data.identity.chips.map((chip) => (
              <span
                key={chip}
                style={{
                  background:
                    chip === 'blocked' || chip === 'cancelled'
                      ? '#FFF1F2'
                      : chip === 'completed' || chip === 'approved'
                        ? '#F0FDF4'
                        : '#EFF6FF',
                  color:
                    chip === 'blocked' || chip === 'cancelled'
                      ? '#E53935'
                      : chip === 'completed' || chip === 'approved'
                        ? green
                        : brandBlue,
                  borderRadius: 8,
                  padding: '3px 10px',
                  fontSize: 11,
                  fontWeight: 700,
                  textTransform: 'capitalize',
                }}
              >
                {chip}
              </span>
            ))}
            {data.identity.joined && (
              <span style={{ color: '#94A3B8', fontSize: 11, alignSelf: 'center' }}>
                Joined {data.identity.joined}
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Stat strip */}
      {!data.notFound && data.stats.length > 0 && (
        <div style={{ display: 'flex', gap: 16, marginBottom: 16, flexWrap: 'wrap' }}>
          {data.stats.map((s) => (
            <StatCard key={s.label} label={s.label} value={s.value} color={brandBlue} />
          ))}
        </div>
      )}

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 4, marginBottom: 14, borderBottom: '2px solid #E2E8F0' }}>
        {TABS.map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            style={{
              background: 'transparent',
              border: 'none',
              borderBottom: tab === t ? `3px solid ${TAB_COLORS[t]}` : '3px solid transparent',
              color: tab === t ? '#0F172A' : '#64748B',
              fontWeight: tab === t ? 800 : 600,
              fontSize: 13,
              padding: '10px 16px',
              cursor: 'pointer',
            }}
          >
            {t} ({tabs[t].items.length})
          </button>
        ))}
      </div>
      <ItemList items={tabs[tab].items} emptyLabel={tabs[tab].empty} />
    </div>
  )
}
