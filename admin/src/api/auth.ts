import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  type User,
} from 'firebase/auth'
import { doc, getDoc } from 'firebase/firestore'
import { auth, db } from '../config/firebase'

export interface AdminUser {
  uid: string
  role: 'admin'
}

export function signIn(email: string, password: string) {
  return signInWithEmailAndPassword(auth, email, password)
}

export function signOut() {
  return firebaseSignOut(auth)
}

/** Reads the users/{uid} doc and returns true only when the role is 'admin'. */
export async function getAdminInfo(uid: string): Promise<AdminUser | null> {
  const snap = await getDoc(doc(db, 'users', uid))
  if (!snap.exists()) return null
  const data = snap.data()
  if (data.role !== 'admin') return null
  return { uid, role: 'admin' }
}

/** Fires with the raw user; callers must still gate on getAdminInfo. */
export function onAuthChange(cb: (user: User | null) => void) {
  return onAuthStateChanged(auth, cb)
}