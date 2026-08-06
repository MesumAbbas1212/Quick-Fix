import { useEffect, useState } from 'react'
import {
  collection,
  getCountFromServer,
  onSnapshot,
  query,
  type Unsubscribe,
} from 'firebase/firestore'
import { db } from '../config/firebase'
import StatCard from '../components/StatCard'

const brandBlue = '#004F9F'
const ctaOrange = '#F36C00'
const green = '#10B981'
const accentGreen = '#B26A00'

export default function AnalyticsPage() {
  const [counts, setCounts] = useState<{ users: number; workers: number; jobs: number }>({
    users: 0,
    workers: 0,
    jobs: 0,
  })
  const [openJobs, setOpenJobs] = useState(0)

  useEffect(() => {
    let active = true
    async function load() {
      try {
        const [users, workers, jobs] = await Promise.all([
          getCountFromServer(query(collection(db, 'users'))),
          getCountFromServer(query(collection(db, 'workers'))),
          getCountFromServer(query(collection(db, 'jobs'))),
        ])
        if (active) {
          setCounts({ users: users.data().count, workers: workers.data().count, jobs: jobs.data().count })
        }
      } catch {
        if (active) setCounts({ users: 0, workers: 0, jobs: 0 })
      }
    }
    load()
    const unsub: Unsubscribe = onSnapshot(query(collection(db, 'jobs')), (snap) => {
      const open = snap.docs.filter((d) => d.data()?.status === 'open').length
      if (active) setOpenJobs(open)
    })
    return () => {
      active = false
      unsub()
    }
  }, [])

  return (
    <div>
      <h2 style={{ color: '#0F172A', fontSize: 20, fontWeight: 800, margin: '0 0 20px' }}>
        Analytics
      </h2>
      <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
        <StatCard label="Total Users" value={counts.users} color={brandBlue} />
        <StatCard label="Workers" value={counts.workers} color={accentGreen} />
        <StatCard label="Total Jobs" value={counts.jobs} color={ctaOrange} />
        <StatCard label="Open Jobs" value={openJobs} color={green} />
      </div>
    </div>
  )
}