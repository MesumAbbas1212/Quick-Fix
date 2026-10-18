import {
  collection,
  doc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  setDoc,
  updateDoc,
  type Unsubscribe,
} from 'firebase/firestore'
import { db } from '../config/firebase'

export interface LanguageRow {
  code: string
  nativeName: string
  englishName: string
  createdAt: string
  isActive: boolean
}

/**
 * The `languages` collection is the source of truth for the multilingual
 * feature (admin-managed). Doc id = BCP-47 code. Deactivating (not
 * deleting) keeps existing `preferredLanguage` values valid.
 */
export function subscribeLanguages(
  cb: (langs: LanguageRow[]) => void,
  onError?: (error: string) => void,
): Unsubscribe {
  const q = query(collection(db, 'languages'), orderBy('englishName'))
  return onSnapshot(
    q,
    (snap) => {
      cb(
        snap.docs.map((d) => {
          const data = d.data()
          return {
            code: d.id,
            nativeName: (data.nativeName as string) ?? '',
            englishName: (data.englishName as string) ?? '',
            createdAt:
              (data.createdAt as { toDate?: () => Date } | null)?.toDate?.()?.toLocaleDateString() ??
              '',
            isActive: data.isActive !== false,
          }
        }),
      )
    },
    (e) => onError?.(e.message),
  )
}

/** BCP-47 pattern: `en`, `pt`, `pt-BR` style tags used by the app. */
export const BCP47_PATTERN = /^[a-z]{2,3}(-[A-Z]{2})?$/

export async function languageCodeExists(code: string): Promise<boolean> {
  const snap = await getDocs(collection(db, 'languages'))
  return snap.docs.some((d) => d.id === code)
}

export async function saveLanguage(
  code: string,
  nativeName: string,
  englishName: string,
) {
  return setDoc(doc(db, 'languages', code), {
    code,
    nativeName,
    englishName,
    isActive: true,
    createdAt: new Date(),
  })
}

export async function updateLanguage(
  code: string,
  nativeName: string,
  englishName: string,
) {
  return updateDoc(doc(db, 'languages', code), {
    nativeName,
    englishName,
    updatedAt: new Date(),
  })
}

/** Soft deactivate: existing preferredLanguage values keep resolving. */
export async function setLanguageActive(code: string, isActive: boolean) {
  return updateDoc(doc(db, 'languages', code), { isActive, updatedAt: new Date() })
}
