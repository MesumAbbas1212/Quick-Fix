import AccountDetailPage from './AccountDetailPage'

/** Thin page: worker account drill-down (A8). */
export default function WorkerDetailPage() {
  return (
    <AccountDetailPage
      kind="worker"
      backTo="/workers"
      backLabel="Back to workers"
      kindLabel="worker"
    />
  )
}
