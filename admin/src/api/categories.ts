import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  onSnapshot,
  query,
  setDoc,
  updateDoc,
  where,
  type Unsubscribe,
} from 'firebase/firestore'
import { db } from '../config/firebase'

export interface CategoryRow {
  id: string
  name: string
  icon: string
  isActive: boolean
}

/**
 * Must mirror the mobile `JobCategory` enum (quickfix/models/job_model.dart)
 * — the app only resolves a category when its `name` is one of these.
 */
export const JOB_CATEGORY_ENUM: string[] = [
  'cleaning',
  'plumbing',
  'electrical',
  'carpentry',
  'painting',
  'gardening',
  'moving',
  'applianceRepair',
  'tutoring',
  'beauty',
  'other',
]

export function subscribeCategories(
  cb: (cats: CategoryRow[]) => void,
  onError?: (error: string) => void,
): Unsubscribe {
  return onSnapshot(
    collection(db, 'categories'),
    (snap) => {
      cb(
        snap.docs.map((d) => {
          const data = d.data()
          return {
            id: d.id,
            name: (data.name as string) ?? '',
            icon: (data.icon as string) ?? '',
            isActive: data.isActive !== false,
          }
        }),
      )
    },
    (e) => onError?.(e.message),
  )
}

export async function saveCategory(id: string, name: string, icon: string, isActive: boolean) {
  return setDoc(doc(db, 'categories', id), { name, icon, isActive })
}

export async function updateCategory(id: string, name: string, icon: string, isActive: boolean) {
  return updateDoc(doc(db, 'categories', id), { name, icon, isActive, updatedAt: new Date() })
}

/**
 * Rename: the document id mirrors the category name, so a rename writes the
 * new doc and removes the old one.
 */
export async function renameCategory(
  oldId: string,
  newName: string,
  icon: string,
  isActive: boolean,
) {
  await setDoc(doc(db, 'categories', newName), {
    name: newName,
    icon,
    isActive,
    updatedAt: new Date(),
  })
  await deleteDoc(doc(db, 'categories', oldId))
}

export async function setCategoryActive(id: string, isActive: boolean) {
  return updateDoc(doc(db, 'categories', id), { isActive, updatedAt: new Date() })
}

/** How many jobs reference this category name (for the rename warning). */
export async function countJobsByCategory(name: string): Promise<number> {
  const snap = await getDocs(query(collection(db, 'jobs'), where('category', '==', name)))
  return snap.size
}
