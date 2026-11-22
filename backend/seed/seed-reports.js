// Seed deterministic, clearly synthetic moderation fixtures and backfill missing user timestamps.
// Default is a read-only dry run. A service account and --write are required to persist.
'use strict'

const SEED_DATE = Date.UTC(2026, 9, 19, 12, 0, 0)
const REPORT_REASONS = [
  "Didn't show up",
  'Rude or unprofessional',
  'Wrong or unsafe work',
  'Fake profile',
  'Asked for payment outside the app',
]
const DETAILS = {
  "Didn't show up": 'Demo report: the scheduled visit was missed and the customer could not reach the worker.',
  'Rude or unprofessional': 'Demo report: the conversation became disrespectful during coordination for the service.',
  'Wrong or unsafe work': 'Demo report: the customer says the completed work did not match the agreed scope and needs a safety review.',
  'Fake profile': 'Demo report: the account details appear inconsistent and should be checked by an administrator.',
  'Asked for payment outside the app': 'Demo report: the customer says they were asked to settle the service payment outside the app.',
}
const RESOLUTION_NOTES = [
  'Demo review: both parties were contacted and the agreed follow-up was recorded.',
  'Demo review: the available evidence was checked and the report was resolved with guidance.',
  'Demo review: the report was reviewed and no further action was needed.',
  'Demo review: the report was dismissed after the submitted details were checked.',
  'Demo review: the available information did not support further moderation action.',
]

function seededRandom(seed = 0x51464958) {
  let value = seed >>> 0
  return () => {
    value += 0x6D2B79F5
    let t = value
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function buildReportPlan({ clients, workers, jobs, adminId, seedDate = SEED_DATE }) {
  if (!clients?.length || !workers?.length || !adminId) {
    throw new Error('Cannot seed reports: the database needs at least one role=user account, one worker, and one role=admin account.')
  }
  clients = [...clients].sort((a, b) => a.id.localeCompare(b.id))
  workers = [...workers].sort((a, b) => a.id.localeCompare(b.id))
  const clientIds = new Set(clients.map((item) => item.id))
  const workerIds = new Set(workers.map((item) => item.id))
  const usableJobs = (jobs || [])
    .filter((job) => clientIds.has(job.userId) && workerIds.has(job.workerId) && job.status === 'completed')
    .sort((a, b) => a.id.localeCompare(b.id))
  const disputeJobs = usableJobs.slice(0, 2)
  if (disputeJobs.length < 2) {
    throw new Error('Cannot seed linked moderation examples: at least two completed jobs must connect a role=user account to a worker account.')
  }

  const random = seededRandom()
  const plan = []
  for (let i = 0; i < 12; i++) {
    const number = i + 1
    const job = i < 6 ? usableJobs[i % usableJobs.length] : null
    const reporterId = job?.userId || clients[Math.floor(random() * clients.length)].id
    let reportedId
    if (job) reportedId = job.workerId
    else if (i % 2 === 0) reportedId = workers[Math.floor(random() * workers.length)].id
    else reportedId = clients.filter((client) => client.id !== reporterId)[Math.floor(random() * Math.max(1, clients.filter((client) => client.id !== reporterId).length))]?.id || workers[0].id

    const status = number <= 7 ? 'open' : number <= 10 ? 'resolved' : 'dismissed'
    const createdAt = new Date(seedDate - (29 - i * 2) * 86400000 - Math.floor(random() * 86400000))
    const row = {
      id: `report-demo-${String(number).padStart(2, '0')}`,
      reporterId,
      reportedId,
      ...(job ? { jobId: job.id } : {}),
      reason: REPORT_REASONS[(number - 1) % REPORT_REASONS.length],
      details: DETAILS[REPORT_REASONS[(number - 1) % REPORT_REASONS.length]],
      status,
      createdAt,
    }
    if (number <= 2) {
      row.disputeId = `report-demo-dispute-${String(number).padStart(2, '0')}`
      row._dispute = {
        id: row.disputeId,
        jobId: job.id,
        raisedBy: reporterId,
        againstId: reportedId,
        category: number === 1 ? 'No-show' : 'Poor quality',
        description: row.details,
        expectedResolution: number === 1 ? 'Other' : 'Partial refund',
        images: [],
        reportId: row.id,
        status: 'open',
        createdAt,
      }
    }
    if (status !== 'open') {
      row.resolutionNote = RESOLUTION_NOTES[number - 8]
      row.resolvedAt = new Date(Math.min(seedDate, createdAt.getTime() + 86400000))
      row.resolvedBy = adminId
    }
    plan.push(row)
  }
  return plan
}

function buildBackfillPlan(users, seedDate = SEED_DATE) {
  return [...users]
    .filter((user) => user.createdAt == null)
    .sort((a, b) => a.id.localeCompare(b.id))
    .map((user, index) => ({ id: user.id, createdAt: new Date(seedDate - (60 + index) * 86400000) }))
}

async function readRows(db, collection, query) {
  let ref = db.collection(collection)
  if (query) ref = ref.where(query.field, '==', query.value)
  const snapshot = await ref.get()
  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }))
}

async function run({ write = false, admin, seedDate = SEED_DATE }) {
  if (write && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('Refusing --write: set GOOGLE_APPLICATION_CREDENTIALS to an authorized service-account JSON file.')
  }
  if (!admin) {
    try { admin = require('firebase-admin') } catch (_) {
      throw new Error('firebase-admin is missing. From backend/seed run npm install.')
    }
  }
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.applicationDefault() })
  const db = admin.firestore()
  const [clients, workers, jobs, admins, userDocs] = await Promise.all([
    readRows(db, 'users', { field: 'role', value: 'user' }),
    readRows(db, 'workers'),
    readRows(db, 'jobs', { field: 'status', value: 'completed' }),
    readRows(db, 'users', { field: 'role', value: 'admin' }),
    readRows(db, 'users'),
  ])
  if (!clients.length || !workers.length || !admins.length) {
    throw new Error('Cannot seed reports: database must contain role=user, role=admin, and worker documents. No writes were made.')
  }
  const adminId = admins.map((item) => item.id).sort()[0]
  const reports = buildReportPlan({ clients, workers, jobs, adminId, seedDate })
  const backfill = buildBackfillPlan(userDocs, seedDate)
  const existingReportDocs = await Promise.all(reports.map((report) => db.collection('reports').doc(report.id).get()))
  const existingDisputeDocs = await Promise.all(reports.filter((report) => report._dispute).map((report) => db.collection('disputes').doc(report.disputeId).get()))
  const skipReportIds = new Set(existingReportDocs.filter((doc) => doc.exists).map((doc) => doc.id))
  const skipDisputeIds = new Set(existingDisputeDocs.filter((doc) => doc.exists).map((doc) => doc.id))
  const output = {
    mode: write ? 'write' : 'dry-run',
    seedDate: new Date(seedDate).toISOString(),
    reports: reports.map(({ _dispute, createdAt, resolvedAt, ...report }) => ({ ...report, createdAt: createdAt.toISOString(), ...(resolvedAt ? { resolvedAt: resolvedAt.toISOString() } : {}) })),
    reportIdsToCreate: reports.filter((report) => !skipReportIds.has(report.id)).map((report) => report.id),
    reportIdsSkipped: [...skipReportIds],
    disputeIdsToCreate: reports.filter((report) => report._dispute && !skipDisputeIds.has(report.disputeId)).map((report) => report.disputeId),
    backfill: backfill.map((item) => ({ ...item, createdAt: item.createdAt.toISOString() })),
    liveWritesPerformed: false,
  }
  if (!write) {
    console.log(JSON.stringify(output, null, 2))
    return output
  }

  const batch = db.batch()
  for (const report of reports) {
    const { _dispute, createdAt, resolvedAt, ...data } = report
    if (!skipReportIds.has(report.id)) {
      batch.create(db.collection('reports').doc(report.id), {
        ...data,
        createdAt: admin.firestore.Timestamp.fromDate(createdAt),
        ...(resolvedAt ? { resolvedAt: admin.firestore.Timestamp.fromDate(resolvedAt) } : {}),
      })
    }
    if (_dispute && !skipDisputeIds.has(_dispute.id)) {
      batch.create(db.collection('disputes').doc(_dispute.id), {
        ..._dispute,
        createdAt: admin.firestore.Timestamp.fromDate(_dispute.createdAt),
      })
    }
  }
  for (const item of backfill) {
    batch.update(db.collection('users').doc(item.id), { createdAt: admin.firestore.Timestamp.fromDate(item.createdAt) })
  }
  if (output.reportIdsToCreate.length || output.disputeIdsToCreate.length || backfill.length) await batch.commit()
  output.liveWritesPerformed = true
  console.log(JSON.stringify(output, null, 2))
  return output
}

if (require.main === module) {
  const write = process.argv.includes('--write')
  run({ write }).catch((error) => {
    console.error(`Seed reports failed: ${error.message}`)
    process.exitCode = 1
  })
}

module.exports = { SEED_DATE, buildReportPlan, buildBackfillPlan, run }
