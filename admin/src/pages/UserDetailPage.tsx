import AccountDetailPage from './AccountDetailPage'

/** Thin page: client account drill-down (A8). */
export default function UserDetailPage() {
  return (
    <AccountDetailPage
      kind="user"
      backTo="/users"
      backLabel="Back to users"
      kindLabel="user"
    />
  )
}
