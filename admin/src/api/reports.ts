import {
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  updateDoc,
  type Unsubscribe,
} from 'firebase/firestore'
import { db } from '../config/firebase'

export interface ReportRow {
  id: string
  reportedBy: string
  reportedUser: string
  reason: string
  status: string
  createdAt: string
}

export function subscribeReports(cb: (reports: ReportRow[]) => void): Unsubscribe {
  const q = query(collection(db, 'reports'), orderBy('createdAt', 'desc'))
  return onSnapshot(q, (snap) => {
    cb(
      snap.docs.map((d) => {
        const data = d.data()
        return {
          id: d.id,
          reportedBy: data.reportedBy ?? '',
          reportedUser: data.reportedUser ?? '',
          reason: data.reason ?? '',
          status: data.status ?? 'open',
          createdAt:
            data.createdAt?.toDate?.()?.toLocaleDateString() ?? '',
        }
      }),
    )
  })
}

export function resolveReport(id: string, status: 'resolved' | 'dismissed') {
  return updateDoc(doc(db, 'reports', id), { status, updatedAt: new Date() })
}