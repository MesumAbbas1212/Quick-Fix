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

export interface WorkerRow {
  id: string
  name: string
  email: string
  professions: string[]
  rating: number
  completedJobs: number
  approved: boolean
  blocked: boolean
}

export function subscribeWorkers(cb: (workers: WorkerRow[]) => void): Unsubscribe {
  const q = query(collection(db, 'workers'), orderBy('createdAt', 'desc'))
  return onSnapshot(q, (snap) => {
    cb(
      snap.docs.map((d) => {
        const data = d.data()
        return {
          id: d.id,
          name: data.fullName ?? '',
          email: data.email ?? '',
          professions: data.professions ?? [],
          rating: data.rating ?? 0,
          completedJobs: data.completedJobs ?? 0,
          approved: data.approved ?? false,
          blocked: data.blocked ?? false,
        }
      }),
    )
  })
}

export function approveWorker(uid: string, approved: boolean) {
  return updateDoc(doc(db, 'workers', uid), { approved, updatedAt: new Date() })
}

export function blockWorker(uid: string, blocked: boolean) {
  return updateDoc(doc(db, 'workers', uid), { blocked, updatedAt: new Date() })
}