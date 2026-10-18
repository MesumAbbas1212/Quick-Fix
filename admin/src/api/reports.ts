import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  updateDoc,
  where,
  type Unsubscribe,
} from 'firebase/firestore'
import { db } from '../config/firebase'

export interface ReportRow {
  id: string
  reporterId: string
  reportedId: string
  reason: string
  details: string
  jobId: string
  status: string
  createdAt: string
}

export function subscribeReports(
  cb: (reports: ReportRow[]) => void,
  onError?: (error: string) => void,
): Unsubscribe {
  const q = query(collection(db, 'reports'), orderBy('createdAt', 'desc'))
  return onSnapshot(
    q,
    (snap) => {
      cb(
        snap.docs.map((d) => {
          const data = d.data()
          return {
            id: d.id,
            reporterId: data.reporterId ?? '',
            reportedId: data.reportedId ?? '',
            reason: data.reason ?? '',
            details: data.details ?? '',
            jobId: data.jobId ?? '',
            status: data.status ?? 'open',
            createdAt: data.createdAt?.toDate?.()?.toLocaleDateString() ?? '',
          }
        }),
      )
    },
    (e) => onError?.(e.message),
  )
}

export interface PersonSummary {
  uid: string
  name: string
  email: string
  phone: string
  role: string
  joined: string
  avatarUrl: string
  // worker-only fields (empty for clients)
  rating: number
  completedJobs: number
}

export interface ReportDetail {
  report: ReportRow & {
    resolutionNote: string
    resolvedAt: string
    resolvedBy: string
  }
  reporter: PersonSummary | null
  reported: PersonSummary | null
  // reported worker's last 10 reviews (empty when not a worker)
  recentReviews: { id: string; rating: number; text: string; lang: string; date: string }[]
  priorReportCount: number
  job: { id: string; title: string; status: string } | null
}

function fmtDate(v: unknown): string {
  const d = (v as { toDate?: () => Date } | null)?.toDate?.()
  return d ? d.toLocaleDateString() : ''
}

function personFromUsers(uid: string, data: Record<string, unknown> | null): PersonSummary | null {
  if (!data) return null
  return {
    uid,
    name: (data.fullName as string) ?? '',
    email: (data.email as string) ?? '',
    phone: (data.phone as string) ?? '',
    role: (data.role as string) ?? 'user',
    joined: fmtDate(data.createdAt),
    avatarUrl: (data.avatarUrl as string) ?? '',
    rating: (data.rating as number) ?? 0,
    completedJobs: (data.completedJobs as number) ?? 0,
  }
}

export async function getReportDetail(reportId: string): Promise<ReportDetail | null> {
  const reportSnap = await getDoc(doc(db, 'reports', reportId))
  if (!reportSnap.exists()) return null
  const rd = reportSnap.data()

  const report: ReportDetail['report'] = {
    id: reportSnap.id,
    reporterId: rd.reporterId ?? '',
    reportedId: rd.reportedId ?? '',
    reason: rd.reason ?? '',
    details: rd.details ?? '',
    jobId: rd.jobId ?? '',
    status: rd.status ?? 'open',
    createdAt: fmtDate(rd.createdAt),
    resolutionNote: rd.resolutionNote ?? '',
    resolvedAt: fmtDate(rd.resolvedAt),
    resolvedBy: rd.resolvedBy ?? '',
  }

  const [reporterDoc, reportedDoc, workerDoc] = await Promise.all([
    getDoc(doc(db, 'users', report.reporterId)).catch(() => null),
    getDoc(doc(db, 'users', report.reportedId)).catch(() => null),
    getDoc(doc(db, 'workers', report.reportedId)).catch(() => null),
  ])

  // Merge worker profile fields (rating/completedJobs) into the reported person.
  const reported = personFromUsers(report.reportedId, reportedDoc?.data() ?? null)
  if (reported && workerDoc?.exists()) {
    const wd = workerDoc.data()
    reported.rating = (wd.rating as number) ?? reported.rating
    reported.completedJobs = (wd.completedJobs as number) ?? reported.completedJobs
    if (!reported.name) reported.name = (wd.fullName as string) ?? ''
  }

  let recentReviews: ReportDetail['recentReviews'] = []
  if (workerDoc?.exists()) {
    const reviewsSnap = await getDocs(
      query(
        collection(db, 'reviews'),
        where('workerId', '==', report.reportedId),
        orderBy('createdAt', 'desc'),
        limit(10),
      ),
    )
    recentReviews = reviewsSnap.docs.map((d) => {
      const v = d.data()
      return {
        id: d.id,
        rating: (v.rating as number) ?? 0,
        text: (v.originalText as string) ?? '',
        lang: (v.originalLang as string) ?? '',
        date: fmtDate(v.createdAt),
      }
    })
  }

  // Prior reports involving the reported account (either direction),
  // excluding this one.
  const [asReported, asReporter] = await Promise.all([
    getDocs(query(collection(db, 'reports'), where('reportedId', '==', report.reportedId))).catch(
      () => null,
    ),
    getDocs(query(collection(db, 'reports'), where('reporterId', '==', report.reportedId))).catch(
      () => null,
    ),
  ])
  const priorReportCount =
    (asReported?.docs.length ?? 0) + (asReporter?.docs.length ?? 0) - 1

  let job: ReportDetail['job'] = null
  if (report.jobId) {
    const jobSnap = await getDoc(doc(db, 'jobs', report.jobId)).catch(() => null)
    if (jobSnap?.exists()) {
      const jd = jobSnap.data()
      job = {
        id: jobSnap.id,
        title: (jd.title as string) ?? '',
        status: (jd.status as string) ?? '',
      }
    }
  }

  return {
    report,
    reporter: personFromUsers(report.reporterId, reporterDoc?.data() ?? null),
    reported,
    recentReviews,
    priorReportCount: Math.max(0, priorReportCount),
    job,
  }
}

export async function resolveReport(
  id: string,
  status: 'resolved' | 'dismissed',
  resolutionNote: string,
  resolvedBy: string,
) {
  return updateDoc(doc(db, 'reports', id), {
    status,
    resolutionNote: resolutionNote.trim(),
    resolvedAt: new Date(),
    resolvedBy,
    updatedAt: new Date(),
  })
}
