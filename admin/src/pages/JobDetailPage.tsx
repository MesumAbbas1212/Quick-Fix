import AccountDetailPage from './AccountDetailPage'

/** Thin page: job drill-down (A8). */
export default function JobDetailPage() {
  return (
    <AccountDetailPage
      kind="job"
      backTo="/jobs"
      backLabel="Back to jobs"
      kindLabel="job"
    />
  )
}
