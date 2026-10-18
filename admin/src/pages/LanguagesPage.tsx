import { useEffect, useState } from 'react'
import DataTable from '../components/DataTable'
import Modal from '../components/Modal'
import {
  errorTextStyle,
  fieldGap,
  inputStyle,
  labelStyle,
  primaryButtonStyle,
  secondaryButtonStyle,
  toastStyle,
} from '../components/fieldStyles'
import {
  BCP47_PATTERN,
  languageCodeExists,
  saveLanguage,
  setLanguageActive,
  subscribeLanguages,
  updateLanguage,
  type LanguageRow,
} from '../api/languages'

const brandBlue = '#004F9F'
const green = '#10B981'
const dangerRed = '#E53935'

interface LanguageForm {
  code: string
  nativeName: string
  englishName: string
}

const emptyForm: LanguageForm = { code: '', nativeName: '', englishName: '' }

export default function LanguagesPage() {
  const [langs, setLangs] = useState<LanguageRow[]>([])
  const [loaded, setLoaded] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [toast, setToast] = useState<{ text: string; error?: boolean } | null>(null)

  const [modal, setModal] = useState<'add' | 'edit' | null>(null)
  const [form, setForm] = useState<LanguageForm>(emptyForm)
  const [editing, setEditing] = useState<LanguageRow | null>(null)
  const [formError, setFormError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    const unsub = subscribeLanguages(
      (rows) => {
        setLangs(rows)
        setLoaded(true)
      },
      (message) => setError(message),
    )
    return unsub
  }, [])

  useEffect(() => {
    if (!toast) return
    const t = setTimeout(() => setToast(null), 3000)
    return () => clearTimeout(t)
  }, [toast])

  function openAdd() {
    setEditing(null)
    setForm(emptyForm)
    setFormError(null)
    setModal('add')
  }

  function openEdit(row: LanguageRow) {
    setEditing(row)
    setForm({ code: row.code, nativeName: row.nativeName, englishName: row.englishName })
    setFormError(null)
    setModal('edit')
  }

  function validate(): string | null {
    const code = form.code.trim()
    const native = form.nativeName.trim()
    const english = form.englishName.trim()
    if (!code) return 'Code is required.'
    if (!BCP47_PATTERN.test(code)) {
      return 'Code must be BCP-47: 2–3 lowercase letters, optionally a 2-letter uppercase region after a dash (e.g. en, ur, pt-BR).'
    }
    if (!native) return 'Native name is required.'
    if (!english) return 'English name is required.'
    if (modal === 'add' && langs.some((l) => l.code === code)) {
      return `Code "${code}" already exists.`
    }
    return null
  }

  async function submit() {
    const problem = validate()
    if (problem) {
      setFormError(problem)
      return
    }
    setSaving(true)
    try {
      const code = form.code.trim()
      if (modal === 'add') {
        const exists = await languageCodeExists(code)
        if (exists) {
          setFormError(`Code "${code}" already exists.`)
          return
        }
        await saveLanguage(code, form.nativeName.trim(), form.englishName.trim())
        setToast({ text: `Language "${code}" added.` })
      } else if (editing) {
        await updateLanguage(
          editing.code,
          form.nativeName.trim(),
          form.englishName.trim(),
        )
        setToast({ text: `Language "${editing.code}" updated.` })
      }
      setModal(null)
    } catch (e) {
      setFormError('Could not save. ' + (e instanceof Error ? e.message : ''))
    } finally {
      setSaving(false)
    }
  }

  async function toggleActive(row: LanguageRow) {
    try {
      await setLanguageActive(row.code, !row.isActive)
      setToast({
        text: row.isActive
          ? `Language "${row.code}" deactivated (existing choices keep working).`
          : `Language "${row.code}" reactivated.`,
      })
    } catch (e) {
      setToast({ text: 'Could not update. ' + (e instanceof Error ? e.message : ''), error: true })
    }
  }

  const activeCount = langs.filter((l) => l.isActive).length

  return (
    <div>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 16,
        }}
      >
        <h2 style={{ color: '#0F172A', fontSize: 20, fontWeight: 800, margin: 0 }}>
          Languages{' '}
          <span style={{ color: '#64748B', fontWeight: 600, fontSize: 13 }}>
            {activeCount} active · {langs.length} total
          </span>
        </h2>
        <button onClick={openAdd} style={primaryButtonStyle}>
          Add language
        </button>
      </div>

      {error && (
        <div style={{ ...errorTextStyle, marginBottom: 12 }}>
          Could not load languages: {error}
        </div>
      )}
      {!loaded && !error ? (
        <div
          style={{
            background: '#fff',
            border: '1px solid #E2E8F0',
            borderRadius: 16,
            padding: 32,
            textAlign: 'center',
            color: '#64748B',
            fontSize: 13,
          }}
        >
          Loading languages…
        </div>
      ) : (
        <DataTable
          rows={langs}
          columns={[
            { key: 'code', header: 'Code', render: (r) => <code style={{ fontWeight: 700 }}>{r.code}</code> },
            {
              key: 'native',
              header: 'Native name',
              render: (r) => (
                <span dir="auto">{r.nativeName || '—'}</span>
              ),
            },
            { key: 'english', header: 'English name', render: (r) => r.englishName || '—' },
            { key: 'added', header: 'Added', render: (r) => r.createdAt || '—' },
            {
              key: 'status',
              header: 'Status',
              render: (r) => (
                <span
                  style={{
                    color: r.isActive ? green : '#64748B',
                    fontWeight: 600,
                    textTransform: 'capitalize',
                  }}
                >
                  {r.isActive ? 'Active' : 'Inactive'}
                </span>
              ),
            },
          ]}
          actions={(r) => (
            <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
              <button onClick={() => openEdit(r)} style={secondaryButtonStyle}>
                Edit
              </button>
              <button
                onClick={() => toggleActive(r)}
                style={{
                  ...secondaryButtonStyle,
                  color: r.isActive ? dangerRed : brandBlue,
                  borderColor: r.isActive ? '#FECDD3' : '#BBD4F0',
                  background: r.isActive ? '#FFF1F2' : '#EFF6FF',
                }}
              >
                {r.isActive ? 'Deactivate' : 'Reactivate'}
              </button>
            </div>
          )}
        />
      )}

      {modal && (
        <Modal title={modal === 'add' ? 'Add language' : `Edit language ${editing?.code}`} onClose={() => setModal(null)}>
          <div style={fieldGap}>
            <label style={labelStyle}>Code (BCP-47)</label>
            <input
              style={inputStyle}
              value={form.code}
              disabled={modal === 'edit'}
              placeholder="e.g. ur, si, ps"
              onChange={(e) => setForm({ ...form, code: e.target.value })}
            />
            {modal === 'add' && (
              <div style={{ fontSize: 11, color: '#94A3B8', marginTop: 4 }}>
                2–3 lowercase letters, optionally a 2-letter region (e.g. en, ur). The code
                becomes the document id — existing choices reference it, so it can never be
                changed or deleted.
              </div>
            )}
          </div>
          <div style={fieldGap}>
            <label style={labelStyle}>Native name</label>
            <input
              style={inputStyle}
              value={form.nativeName}
              placeholder="e.g. اردو"
              dir="auto"
              onChange={(e) => setForm({ ...form, nativeName: e.target.value })}
            />
          </div>
          <div style={fieldGap}>
            <label style={labelStyle}>English name</label>
            <input
              style={inputStyle}
              value={form.englishName}
              placeholder="e.g. Urdu"
              onChange={(e) => setForm({ ...form, englishName: e.target.value })}
            />
          </div>
          {formError && <div style={{ ...errorTextStyle, marginBottom: 12 }}>{formError}</div>}
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
            <button onClick={() => setModal(null)} style={secondaryButtonStyle}>
              Cancel
            </button>
            <button onClick={submit} disabled={saving} style={{ ...primaryButtonStyle, opacity: saving ? 0.6 : 1 }}>
              {saving ? 'Saving…' : modal === 'add' ? 'Add language' : 'Save changes'}
            </button>
          </div>
        </Modal>
      )}

      {toast && <div style={toastStyle(Boolean(toast.error))}>{toast.text}</div>}
    </div>
  )
}
