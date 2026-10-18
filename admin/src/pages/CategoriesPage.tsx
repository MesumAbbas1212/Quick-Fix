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
  countJobsByCategory,
  JOB_CATEGORY_ENUM,
  renameCategory,
  saveCategory,
  setCategoryActive,
  subscribeCategories,
  updateCategory,
  type CategoryRow,
} from '../api/categories'

const brandBlue = '#004F9F'
const green = '#10B981'
const amber = '#F59E0B'

interface CategoryForm {
  name: string
  icon: string
  isActive: boolean
}

const emptyForm: CategoryForm = { name: '', icon: '', isActive: true }

export default function CategoriesPage() {
  const [cats, setCats] = useState<CategoryRow[]>([])
  const [loaded, setLoaded] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [toast, setToast] = useState<{ text: string; error?: boolean } | null>(null)

  const [modal, setModal] = useState<'add' | 'edit' | null>(null)
  const [form, setForm] = useState<CategoryForm>(emptyForm)
  const [editing, setEditing] = useState<CategoryRow | null>(null)
  const [formError, setFormError] = useState<string | null>(null)
  const [renameWarning, setRenameWarning] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    const unsub = subscribeCategories(
      (rows) => {
        setCats(rows)
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

  // Warn (non-blocking) when renaming a category that jobs already reference.
  useEffect(() => {
    if (!modal || !editing) {
      setRenameWarning(null)
      return
    }
    const name = form.name.trim()
    if (!name || name === editing.name) {
      setRenameWarning(null)
      return
    }
    let cancelled = false
    countJobsByCategory(editing.name)
      .then((count) => {
        if (cancelled) return
        setRenameWarning(
          count > 0
            ? `${count} job(s) already reference "${editing.name}". Renaming will not update those jobs.`
            : null,
        )
      })
      .catch(() => {
        if (!cancelled) setRenameWarning(null)
      })
    return () => {
      cancelled = true
    }
  }, [form.name, modal, editing])

  function openAdd() {
    setEditing(null)
    setForm(emptyForm)
    setFormError(null)
    setModal('add')
  }

  function openEdit(row: CategoryRow) {
    setEditing(row)
    setForm({ name: row.name, icon: row.icon, isActive: row.isActive })
    setFormError(null)
    setModal('edit')
  }

  function validate(): string | null {
    const name = form.name.trim()
    if (!name) return 'Name is required.'
    if (!JOB_CATEGORY_ENUM.includes(name)) {
      return `"${name}" is not a valid JobCategory value. The app only resolves: ${JOB_CATEGORY_ENUM.join(', ')}.`
    }
    if (modal === 'add' && cats.some((c) => c.name === name)) {
      return `A category named "${name}" already exists.`
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
      const name = form.name.trim()
      const icon = form.icon.trim()
      if (modal === 'add') {
        await saveCategory(name, name, icon, form.isActive)
        setToast({ text: `Category "${name}" added.` })
      } else if (editing) {
        if (name !== editing.name) {
          await renameCategory(editing.id, name, icon, form.isActive)
          setToast({ text: `Category renamed to "${name}".` })
        } else {
          await updateCategory(editing.id, name, icon, form.isActive)
          setToast({ text: `Category "${name}" updated.` })
        }
      }
      setModal(null)
    } catch (e) {
      setFormError('Could not save. ' + (e instanceof Error ? e.message : ''))
    } finally {
      setSaving(false)
    }
  }

  async function toggleActive(row: CategoryRow) {
    try {
      await setCategoryActive(row.id, !row.isActive)
      setToast({
        text: row.isActive ? `Category "${row.name}" deactivated.` : `Category "${row.name}" reactivated.`,
      })
    } catch (e) {
      setToast({ text: 'Could not update. ' + (e instanceof Error ? e.message : ''), error: true })
    }
  }

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
          Categories{' '}
          <span style={{ color: '#64748B', fontWeight: 600, fontSize: 13 }}>
            {cats.filter((c) => c.isActive).length} active · {cats.length} total
          </span>
        </h2>
        <button onClick={openAdd} style={primaryButtonStyle}>
          Add category
        </button>
      </div>

      {error && (
        <div style={{ ...errorTextStyle, marginBottom: 12 }}>Could not load categories: {error}</div>
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
          Loading categories…
        </div>
      ) : (
        <DataTable
          rows={cats}
          columns={[
            { key: 'name', header: 'Name', render: (r) => <span style={{ fontWeight: 700 }}>{r.name || r.id}</span> },
            { key: 'icon', header: 'Icon key', render: (r) => (r.icon ? <code>{r.icon}</code> : '—') },
            {
              key: 'active',
              header: 'Active',
              render: (r) => (
                <span style={{ color: r.isActive ? green : '#64748B', fontWeight: 600 }}>
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
                  color: r.isActive ? brandBlue : green,
                  borderColor: r.isActive ? '#BBD4F0' : '#A7F3D0',
                  background: r.isActive ? '#EFF6FF' : '#F0FDF4',
                }}
              >
                {r.isActive ? 'Deactivate' : 'Reactivate'}
              </button>
            </div>
          )}
        />
      )}

      {modal && (
        <Modal
          title={modal === 'add' ? 'Add category' : `Edit category ${editing?.name}`}
          onClose={() => setModal(null)}
        >
          <div style={fieldGap}>
            <label style={labelStyle}>Name (JobCategory enum value)</label>
            <input
              style={inputStyle}
              list="job-category-options"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="e.g. plumbing"
            />
            <datalist id="job-category-options">
              {JOB_CATEGORY_ENUM.map((c) => (
                <option key={c} value={c} />
              ))}
            </datalist>
          </div>
          <div style={fieldGap}>
            <label style={labelStyle}>Icon key (optional)</label>
            <input
              style={inputStyle}
              value={form.icon}
              onChange={(e) => setForm({ ...form, icon: e.target.value })}
              placeholder="e.g. wrench"
            />
          </div>
          <div style={fieldGap}>
            <label
              style={{ ...labelStyle, display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}
            >
              <input
                type="checkbox"
                checked={form.isActive}
                onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
              />
              Active
            </label>
          </div>
          {formError && <div style={{ ...errorTextStyle, marginBottom: 12 }}>{formError}</div>}
          {renameWarning && (
            <div
              style={{
                background: '#FFFBEB',
                border: '1px solid #FDE68A',
                color: amber,
                borderRadius: 10,
                padding: '8px 12px',
                fontSize: 12,
                fontWeight: 600,
                marginBottom: 12,
              }}
            >
              {renameWarning}
            </div>
          )}
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
            <button onClick={() => setModal(null)} style={secondaryButtonStyle}>
              Cancel
            </button>
            <button
              onClick={submit}
              disabled={saving}
              style={{ ...primaryButtonStyle, opacity: saving ? 0.6 : 1 }}
            >
              {saving ? 'Saving…' : modal === 'add' ? 'Add category' : 'Save changes'}
            </button>
          </div>
        </Modal>
      )}

      {toast && <div style={toastStyle(Boolean(toast.error))}>{toast.text}</div>}
    </div>
  )
}
