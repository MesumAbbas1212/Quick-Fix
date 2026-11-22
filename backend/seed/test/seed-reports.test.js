'use strict'
const { test } = require('node:test')
const assert = require('node:assert/strict')
const { SEED_DATE, buildBackfillPlan, buildReportPlan, run } = require('../seed-reports')

const sources = {
  clients: [{ id: 'client-a' }, { id: 'client-b' }],
  workers: [{ id: 'worker-a' }, { id: 'worker-b' }],
  jobs: [
    { id: 'job-b', userId: 'client-b', workerId: 'worker-b', status: 'completed' },
    { id: 'job-a', userId: 'client-a', workerId: 'worker-a', status: 'completed' },
  ],
  adminId: 'admin-a',
}

test('report plan is deterministic, fixed-id, and has the requested statuses and dispute links', () => {
  const first = buildReportPlan(sources)
  assert.deepEqual(buildReportPlan(sources), first)
  assert.deepEqual(first.map((report) => report.id), Array.from({ length: 12 }, (_, i) => `report-demo-${String(i + 1).padStart(2, '0')}`))
  assert.deepEqual(first.reduce((counts, report) => ({ ...counts, [report.status]: counts[report.status] + 1 }), { open: 0, resolved: 0, dismissed: 0 }), { open: 7, resolved: 3, dismissed: 2 })
  assert.deepEqual(first.slice(0, 2).map((report) => report.disputeId), ['report-demo-dispute-01', 'report-demo-dispute-02'])
  assert.ok(first.slice(0, 2).every((report) => report._dispute.raisedBy === report.reporterId && report._dispute.againstId === report.reportedId && report._dispute.jobId === report.jobId))
  assert.equal(first.filter((report) => report.jobId).length, 6)
  assert.ok(first.every((report) => report.createdAt <= new Date(SEED_DATE) && report.createdAt >= new Date(SEED_DATE - 30 * 86400000)))
  assert.ok(first.filter((report) => report.status !== 'open').every((report) => report.resolutionNote && report.resolvedAt && report.resolvedBy === 'admin-a'))
})

test('user timestamp backfill is a deterministic spread and leaves existing timestamps alone', () => {
  const users = [{ id: 'missing-b' }, { id: 'set', createdAt: new Date(SEED_DATE) }, { id: 'missing-a' }]
  const planned = buildBackfillPlan(users)
  assert.deepEqual(planned, buildBackfillPlan(users))
  assert.deepEqual(planned.map((row) => row.id), ['missing-a', 'missing-b'])
  assert.ok(planned[1].createdAt < planned[0].createdAt)
})

test('dry-run does not commit writes and write mode requires an explicit service-account path', async () => {
  let commits = 0
  const docsByCollection = {
    users: [
      { id: 'client-a', data: () => ({ role: 'user', fullName: 'Client A' }) },
      { id: 'admin-a', data: () => ({ role: 'admin' }) },
    ],
    workers: [{ id: 'worker-a', data: () => ({ fullName: 'Worker A' }) }],
    jobs: [{ id: 'job-a', data: () => ({ userId: 'client-a', workerId: 'worker-a', status: 'completed' }) },
      { id: 'job-b', data: () => ({ userId: 'client-a', workerId: 'worker-a', status: 'completed' }) }],
  }
  const db = {
    collection(name) {
      const rows = docsByCollection[name] || []
      return {
        where(field, operator, value) {
          assert.equal(operator, '==')
          return { get: async () => ({ docs: rows.filter((row) => row.data()[field] === value) }) }
        },
        get: async () => ({ docs: rows }),
        doc(id) { return { id, get: async () => ({ id, exists: false }) } },
      }
    },
    batch() { return { create() {}, update() {}, commit: async () => { commits++ } } },
  }
  const fakeAdmin = {
    apps: [],
    credential: { applicationDefault: () => ({}) },
    initializeApp() { this.apps.push({}) },
    firestore: Object.assign(() => db, { Timestamp: { fromDate: (date) => date } }),
  }
  const savedCredentials = process.env.GOOGLE_APPLICATION_CREDENTIALS
  const savedLog = console.log
  delete process.env.GOOGLE_APPLICATION_CREDENTIALS
  console.log = () => {}
  try {
    const output = await run({ admin: fakeAdmin })
    assert.equal(output.mode, 'dry-run')
    assert.equal(output.liveWritesPerformed, false)
    assert.equal(commits, 0)
    await assert.rejects(() => run({ write: true, admin: fakeAdmin }), /GOOGLE_APPLICATION_CREDENTIALS/)
  } finally {
    console.log = savedLog
    if (savedCredentials === undefined) delete process.env.GOOGLE_APPLICATION_CREDENTIALS
    else process.env.GOOGLE_APPLICATION_CREDENTIALS = savedCredentials
  }
})
