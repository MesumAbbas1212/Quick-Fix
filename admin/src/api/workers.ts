import {
  collection, doc, getDoc, onSnapshot, orderBy, query, runTransaction, serverTimestamp, updateDoc,
  type Unsubscribe,
} from 'firebase/firestore'
import { auth, db } from '../config/firebase'

export type VerificationStatus = 'notStarted' | 'pending' | 'verified' | 'rejected'
export interface WorkerRow {
  id: string
  name: string
  email: string
  professions: string[]
  rating: number
  completedJobs: number
  approved: boolean
  blocked: boolean
  verificationStatus: VerificationStatus
}
export interface VerificationReview {
  status: VerificationStatus
  hasFront: boolean
  hasBack: boolean
  hasSelfie: boolean
  consent: boolean
  note: string
}
function status(value: unknown): VerificationStatus {
  return value === 'pending' || value === 'verified' || value === 'rejected' ? value : 'notStarted'
}
function bounded<T>(promise: Promise<T>): Promise<T> {
  let timeout: ReturnType<typeof setTimeout>
  return Promise.race([promise, new Promise<never>((_, reject) => {
    timeout = setTimeout(() => reject(new Error('Request timed out. Refresh before retrying.')), 12000)
  })]).finally(() => clearTimeout(timeout))
}
export function subscribeWorkers(cb: (workers: WorkerRow[]) => void, onError?: (error: Error) => void): Unsubscribe {
  const q = query(collection(db, 'workers'), orderBy('createdAt', 'desc'))
  return onSnapshot(q, (snap) => cb(snap.docs.map((d) => {
    const data = d.data()
    return {
      id: d.id, name: data.fullName ?? '', email: data.email ?? '', professions: data.professions ?? [],
      rating: data.rating ?? 0, completedJobs: data.completedJobs ?? 0, approved: data.approved ?? false,
      blocked: data.blocked ?? false, verificationStatus: status(data.verification?.status),
    }
  })), onError)
}
export function approveWorker(uid: string, approved: boolean) {
  return bounded(updateDoc(doc(db, 'workers', uid), { approved, updatedAt: serverTimestamp() }))
}
export function blockWorker(uid: string, blocked: boolean) {
  return bounded(updateDoc(doc(db, 'workers', uid), { blocked, updatedAt: serverTimestamp() }))
}
export async function getWorkerVerification(uid: string): Promise<VerificationReview | null> {
  const snapshot = await bounded(getDoc(doc(db, 'workerVerifications', uid)))
  if (!snapshot.exists()) return null
  const data = snapshot.data()
  // Do not return local paths to the UI as if they were remotely accessible images.
  return { status: status(data.status), consent: data.consent === true,
    hasFront: Boolean(data.cnicFrontPath), hasBack: Boolean(data.cnicBackPath), hasSelfie: Boolean(data.selfiePath), note: data.note ?? '' }
}
export async function reviewWorkerVerification(uid: string, next: 'verified' | 'rejected', note: string, confirmedExternalCheck: boolean): Promise<void> {
  const reviewer = auth.currentUser?.uid
  if (!reviewer) throw new Error('Sign in again before reviewing.')
  if (next === 'verified' && !confirmedExternalCheck) throw new Error('Confirm a separate secure or in-person identity check first.')
  if (next === 'rejected' && !note.trim()) throw new Error('A rejection reason is required.')
  if (note.length > 1000) throw new Error('Keep the review note within 1,000 characters.')
  const privateRef = doc(db, 'workerVerifications', uid)
  const workerRef = doc(db, 'workers', uid)
  await bounded(runTransaction(db, async (transaction) => {
    const [proof, worker] = await Promise.all([transaction.get(privateRef), transaction.get(workerRef)])
    if (!proof.exists() || !worker.exists()) throw new Error('This worker has no submitted verification.')
    const data = proof.data()
    if (data.status !== 'pending' && data.status !== 'verified') throw new Error('Only a pending request or an existing verification can be reviewed. Refresh the list.')
    if (next === 'verified' && (!data.consent || !data.cnicFrontPath || !data.cnicBackPath || !data.selfiePath || !data.submittedAt)) {
      throw new Error('The request is incomplete; do not mark it verified.')
    }
    transaction.update(privateRef, { status: next, note: note.trim(), reviewedAt: serverTimestamp(), reviewedBy: reviewer, reviewMethod: 'manual-external' })
    transaction.update(workerRef, { verification: { status: next, submittedAt: data.submittedAt, reviewedAt: serverTimestamp() }, updatedAt: serverTimestamp() })
  }))
}
