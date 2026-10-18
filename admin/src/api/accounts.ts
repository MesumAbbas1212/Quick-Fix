import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  where,
} from 'firebase/firestore'
import { db } from '../config/firebase'

export type DetailKind = 'user' | 'worker' | 'job'

export interface DetailItem {
  id: string
  title: string
  sub: string
  date: string
  extra: string
}

export interface AccountDetailData {
  kind: DetailKind
  id: string
  notFound: boolean
  identity: {
    name: string
    subtitle: string
    role: string
    joined: string
    chips: string[]
    avatarUrl: string
  }
  stats: { label: string; value: string }[]
  tabs: {
    activity: DetailItem[]
    reviews: DetailItem[]
    payments: DetailItem[]
    reports: DetailItem[]
  }
}

function fmtDate(v: unknown): string {
  const d = (v as { toDate?: () => Date } | null)?.toDate?.()
  return d ? d.toLocaleDateString() : ''
}

function num(v: unknown, fallback = 0): number {
  const n = typeof v === 'number' ? v : Number(v)
  return Number.isFinite(n) ? n : fallback
}

async function jobsForUser(uid: string): Promise<DetailItem[]> {
  const snap = await getDocs(
    query(collection(db, 'jobs'), where('userId', '==', uid)),
  ).catch(() => null)
  if (!snap) return []
  return snap.docs.map((d) => {
    const j = d.data()
    return {
      id: d.id,
      title: (j.title as string) ?? '—',
      sub: (j.category as string) ?? '',
      date: fmtDate(j.createdAt),
      extra: String(j.status ?? ''),
    }
  })
}

async function jobsForWorker(uid: string): Promise<DetailItem[]> {
  const snap = await getDocs(
    query(collection(db, 'jobs'), where('workerId', '==', uid)),
  ).catch(() => null)
  if (!snap) return []
  return snap.docs.map((d) => {
    const j = d.data()
    return {
      id: d.id,
      title: (j.title as string) ?? '—',
      sub: (j.category as string) ?? '',
      date: fmtDate(j.createdAt),
      extra: String(j.status ?? ''),
    }
  })
}

async function reviewsForReviewer(uid: string): Promise<DetailItem[]> {
  const snap = await getDocs(
    query(collection(db, 'reviews'), where('reviewerId', '==', uid)),
  ).catch(() => null)
  if (!snap) return []
  return snap.docs.map((d) => {
    const r = d.data()
    return {
      id: d.id,
      title: `${num(r.rating).toFixed(1)} ★`,
      sub: String((r.originalText as string) ?? '').slice(0, 80),
      date: fmtDate(r.createdAt),
      extra: String(r.originalLang ?? ''),
    }
  })
}

async function reviewsForWorker(uid: string): Promise<DetailItem[]> {
  const snap = await getDocs(
    query(collection(db, 'reviews'), where('workerId', '==', uid)),
  ).catch(() => null)
  if (!snap) return []
  return snap.docs.map((d) => {
    const r = d.data()
    return {
      id: d.id,
      title: `${num(r.rating).toFixed(1)} ★`,
      sub: String((r.originalText as string) ?? '').slice(0, 80),
      date: fmtDate(r.createdAt),
      extra: String(r.originalLang ?? ''),
    }
  })
}

async function paymentsByPayer(uid: string): Promise<DetailItem[]> {
  const snap = await getDocs(
    query(collection(db, 'payments'), where('payerId', '==', uid)),
  ).catch(() => null)
  return mapPayments(snap)
}

async function paymentsByWorker(uid: string): Promise<DetailItem[]> {
  const snap = await getDocs(
    query(collection(db, 'payments'), where('workerId', '==', uid)),
  ).catch(() => null)
  return mapPayments(snap)
}

function mapPayments(
  snap: { docs: { id: string; data: () => Record<string, unknown> }[] } | null,
): DetailItem[] {
  if (!snap) return []
  return snap.docs.map((d) => {
    const p = d.data()
    return {
      id: d.id,
      title: `PKR ${num(p.amount).toLocaleString()}`,
      sub: String(p.jobId ?? ''),
      date: fmtDate(p.createdAt),
      extra: String(p.status ?? ''),
    }
  })
}

async function reportsInvolving(uid: string): Promise<DetailItem[]> {
  const [asReporter, asReported] = await Promise.all([
    getDocs(query(collection(db, 'reports'), where('reporterId', '==', uid))).catch(() => null),
    getDocs(query(collection(db, 'reports'), where('reportedId', '==', uid))).catch(() => null),
  ])
  const seen = new Set<string>()
  const items: DetailItem[] = []
  for (const snap of [asReporter, asReported]) {
    if (!snap) continue
    for (const d of snap.docs) {
      if (seen.has(d.id)) continue
      seen.add(d.id)
      const r = d.data()
      items.push({
        id: d.id,
        title: String(r.reason ?? ''),
        sub:
          r.reporterId === uid ? 'Reported by this account' : 'This account was reported',
        date: fmtDate(r.createdAt),
        extra: String(r.status ?? ''),
      })
    }
  }
  return items
}

export async function getAccountDetail(kind: DetailKind, id: string): Promise<AccountDetailData> {
  if (kind === 'user' || kind === 'worker') {
    return getUserOrWorkerDetail(kind, id)
  }
  return getJobDetail(id)
}

async function getUserOrWorkerDetail(kind: 'user' | 'worker', uid: string): Promise<AccountDetailData> {
  const userSnap = await getDoc(doc(db, 'users', uid)).catch(() => null)
  if (!userSnap?.exists()) {
    return emptyDetail(kind, uid, 'Unknown account')
  }
  const u = userSnap.data()
  const workerSnap =
    kind === 'worker' ? await getDoc(doc(db, 'workers', uid)).catch(() => null) : null
  const w = workerSnap?.exists() ? workerSnap.data() : null

  const [activity, reviews, payments, reports] = await Promise.all([
    kind === 'worker' ? jobsForWorker(uid) : jobsForUser(uid),
    kind === 'worker' ? reviewsForWorker(uid) : reviewsForReviewer(uid),
    kind === 'worker' ? paymentsByWorker(uid) : paymentsByPayer(uid),
    reportsInvolving(uid),
  ])

  const name = (u.fullName as string) || 'Unknown account'
  const role = (u.role as string) ?? 'user'
  const chips = [
    role,
    u.blocked ? 'blocked' : 'active',
    ...(w ? [w.approved ? 'approved' : 'pending approval', w.blocked ? 'blocked' : '']
      .filter(Boolean)
      : []),
  ]

  return {
    kind,
    id: uid,
    notFound: false,
    identity: {
      name,
      subtitle:
        [u.email, u.phone].filter(Boolean).join(' · ') || (w?.email as string) || '',
      role,
      joined: fmtDate(u.createdAt),
      chips,
      avatarUrl: (u.avatarUrl as string) ?? (w?.avatarUrl as string) ?? '',
    },
    stats: [
      {
        label: kind === 'worker' ? 'Jobs done' : 'Jobs posted',
        value: String(activity.length),
      },
      {
        label: 'Rating',
        value: `${(w?.rating as number) ?? (u.rating as number) ?? 0} ★`,
      },
      {
        label: kind === 'worker' ? 'Reviews received' : 'Reviews written',
        value: String(reviews.length),
      },
      { label: 'Payments', value: String(payments.length) },
      { label: 'Reports', value: String(reports.length) },
    ],
    tabs: { activity, reviews, payments, reports },
  }
}

async function getJobDetail(jobId: string): Promise<AccountDetailData> {
  const jobSnap = await getDoc(doc(db, 'jobs', jobId)).catch(() => null)
  if (!jobSnap?.exists()) {
    return emptyDetail('job', jobId, 'Unknown job')
  }
  const j = jobSnap.data()
  const clientUid = (j.userId as string) ?? ''
  const workerUid = (j.workerId as string) ?? ''

  const [clientSnap, workerSnap] = await Promise.all([
    getDoc(doc(db, 'users', clientUid)).catch(() => null),
    getDoc(doc(db, 'users', workerUid)).catch(() => null),
  ])
  const clientName = clientSnap?.exists()
    ? (clientSnap.data().fullName as string) ?? ''
    : ''
  const workerName = workerSnap?.exists()
    ? (workerSnap.data().fullName as string) ?? ''
    : ''

  const [requests, reviews, payments, reports] = await Promise.all([
    getDocs(query(collection(db, 'jobRequests'), where('jobId', '==', jobId))).catch(() => null),
    getDocs(query(collection(db, 'reviews'), where('jobId', '==', jobId))).catch(() => null),
    getDocs(query(collection(db, 'payments'), where('jobId', '==', jobId))).catch(() => null),
    getDocs(query(collection(db, 'reports'), where('jobId', '==', jobId))).catch(() => null),
  ])

  const activity: DetailItem[] = (requests?.docs ?? []).map((d) => {
    const r = d.data()
    return {
      id: d.id,
      title: 'Application',
      sub: String(r.workerId ?? ''),
      date: fmtDate(r.createdAt),
      extra: String(r.status ?? ''),
    }
  })
  const reviewItems: DetailItem[] = (reviews?.docs ?? []).map((d) => {
    const r = d.data()
    return {
      id: d.id,
      title: `${num(r.rating).toFixed(1)} ★`,
      sub: String((r.originalText as string) ?? '').slice(0, 80),
      date: fmtDate(r.createdAt),
      extra: String(r.originalLang ?? ''),
    }
  })
  const paymentList: DetailItem[] = mapPayments(payments)
  const reportItems: DetailItem[] = (reports?.docs ?? []).map((d) => {
    const r = d.data()
    return {
      id: d.id,
      title: String(r.reason ?? ''),
      sub: String(r.reportedId ?? ''),
      date: fmtDate(r.createdAt),
      extra: String(r.status ?? ''),
    }
  })

  const budget = `PKR ${num(j.budgetMin).toLocaleString()} – ${num(j.budgetMax).toLocaleString()}`
  const status = String(j.status ?? '')

  return {
    kind: 'job',
    id: jobId,
    notFound: false,
    identity: {
      name: (j.title as string) || 'Untitled job',
      subtitle: [j.category, j.address].filter(Boolean).join(' · ') || '',
      role: 'job',
      joined: fmtDate(j.createdAt),
      chips: [status, j.category ?? ''].filter(Boolean),
      avatarUrl: '',
    },
    stats: [
      { label: 'Budget', value: budget },
      { label: 'Client', value: clientName || '—' },
      { label: 'Worker', value: workerName || '—' },
      { label: 'Applicants', value: String(requests?.size ?? 0) },
      { label: 'Reports', value: String(reports?.size ?? 0) },
    ],
    tabs: {
      activity,
      reviews: reviewItems,
      payments: paymentList,
      reports: reportItems,
    },
  }
}

function emptyDetail(kind: DetailKind, id: string, name: string): AccountDetailData {
  return {
    kind,
    id,
    notFound: true,
    identity: { name, subtitle: '', role: kind, joined: '', chips: [], avatarUrl: '' },
    stats: [],
    tabs: { activity: [], reviews: [], payments: [], reports: [] },
  }
}
