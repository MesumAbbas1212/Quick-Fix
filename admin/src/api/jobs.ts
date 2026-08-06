import {
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  orderBy,
  query,
  type Unsubscribe,
} from 'firebase/firestore'
import { db } from '../config/firebase'

export interface JobRow {
  id: string
  title: string
  category: string
  status: string
  createdAt: string
}

export function subscribeJobs(cb: (jobs: JobRow[]) => void): Unsubscribe {
  const q = query(collection(db, 'jobs'), orderBy('createdAt', 'desc'))
  return onSnapshot(q, (snap) => {
    cb(
      snap.docs.map((d) => {
        const data = d.data()
        return {
          id: d.id,
          title: data.title ?? '',
          category: data.category ?? '',
          status: data.status ?? 'open',
          createdAt:
            data.createdAt?.toDate?.()?.toLocaleDateString() ?? '',
        }
      }),
    )
  })
}

export function deleteJob(id: string) {
  return deleteDoc(doc(db, 'jobs', id))
}
