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

export interface UserRow {
  id: string
  name: string
  email: string
  phone: string
  role: string
  blocked: boolean
}

export function subscribeUsers(cb: (users: UserRow[]) => void): Unsubscribe {
  const q = query(collection(db, 'users'), orderBy('createdAt', 'desc'))
  return onSnapshot(q, (snap) => {
    cb(
      snap.docs.map((d) => {
        const data = d.data()
        return {
          id: d.id,
          name: data.fullName ?? '',
          email: data.email ?? '',
          phone: data.phone ?? '',
          role: data.role ?? 'user',
          blocked: data.blocked ?? false,
        }
      }),
    )
  })
}

export function blockUser(uid: string, blocked: boolean) {
  return updateDoc(doc(db, 'users', uid), { blocked, updatedAt: new Date() })
}
