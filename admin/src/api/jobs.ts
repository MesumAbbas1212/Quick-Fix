import {
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  where,
  writeBatch,
} from 'firebase/firestore'
import { auth, db } from '../config/firebase'

export interface JobRow {
  id: string
  title: string
  category: string
  status: string
  createdAt: string
}

export interface JobDeletionResult {
  jobRequests: number
  privateDocs: number
  notifications: number
}

/** Firestore caps a batch at 500 writes. */
const BATCH_LIMIT = 500

type Unsubscribe = () => void

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

type DeleteOp = (batch: ReturnType<typeof writeBatch>) => void

/** Commits `ops` in batches of at most 500, stopping at the first failure. */
async function commitAll(ops: DeleteOp[], step: string) {
  try {
    for (let start = 0; start < ops.length; start += BATCH_LIMIT) {
      const batch = writeBatch(db)
      for (const op of ops.slice(start, start + BATCH_LIMIT)) op(batch)
      await batch.commit()
    }
  } catch (error) {
    throw new Error(`Delete stopped while removing ${step}: ${String(error)}`)
  }
}

/**
 * Permanently deletes a job with the same cascade as the mobile admin screen
 * (`JobService.deleteJob` in mobile/lib/services/job_service.dart), so both
 * consoles leave the database in the same state:
 *
 *  - removes the job, its photos/subcollections, its applications
 *    (jobRequests, including their private subdocuments) and the notifications
 *    that point at it;
 *  - keeps payments and reviews, which are financial/reputational evidence;
 *  - writes `deletedJobs/{jobId}` in the same batch as the job delete, so the
 *    audit trail can never be missing.
 */
export async function deleteJobWithReason(
  id: string,
  reason: string,
): Promise<JobDeletionResult> {
  const trimmed = reason.trim()
  if (!trimmed) throw new Error('A deletion reason is required.')
  const adminId = auth.currentUser?.uid
  if (!adminId) throw new Error('Sign in as an admin before deleting a job.')

  const jobRef = doc(db, 'jobs', id)
  const job = await getDoc(jobRef)
  if (!job.exists()) throw new Error('Job no longer exists.')

  // Read what else points at this job before destroying anything.
  const [requestSnap, notificationSnap, privateSnap] = await Promise.all([
    getDocs(query(collection(db, 'jobRequests'), where('jobId', '==', id))),
    getDocs(
      query(
        collection(db, 'notifications'),
        where('refId', '==', id),
        where('type', 'in', ['job', 'jobRequest', 'request']),
      ),
    ),
    getDocs(collection(db, 'jobs', id, 'private')),
  ])

  // Applications, plus anything filed under each application.
  const requestOps: DeleteOp[] = []
  for (const request of requestSnap.docs) {
    requestOps.push((batch) => batch.delete(request.ref))
    const children = await getDocs(collection(db, 'jobRequests', request.id, 'private'))
    for (const child of children.docs) {
      requestOps.push((batch) => batch.delete(child.ref))
    }
  }
  await commitAll(requestOps, 'applications')

  await commitAll(
    privateSnap.docs.map((d) => (batch) => batch.delete(d.ref)),
    'private documents',
  )

  await commitAll(
    notificationSnap.docs.map((d) => (batch) => batch.delete(d.ref)),
    'notifications',
  )

  const data = job.data() ?? {}
  const audit = {
    jobId: id,
    title: data.title ?? '',
    category: data.category ?? '',
    ownerId: data.userId ?? '',
    workerId: data.workerId ?? null,
    status: data.status ?? '',
    budgetMin: data.budgetMin ?? 0,
    budgetMax: data.budgetMax ?? 0,
    createdAt: data.createdAt ?? null,
    deletedAt: serverTimestamp(),
    deletedBy: adminId,
    reason: trimmed,
    cascaded: {
      jobRequests: requestSnap.size,
      privateDocs: privateSnap.size,
      notifications: notificationSnap.size,
    },
  }

  // The job delete and its audit record share one batch: the evidence is
  // written if and only if the record disappears.
  await commitAll(
    [
      (batch) => batch.delete(jobRef),
      (batch) => batch.set(doc(collection(db, 'deletedJobs'), id), audit),
    ],
    'the job',
  )

  return {
    jobRequests: requestSnap.size,
    privateDocs: privateSnap.size,
    notifications: notificationSnap.size,
  }
}
