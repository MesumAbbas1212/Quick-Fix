import { after, before, beforeEach, test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { initializeTestEnvironment, assertSucceeds } from '@firebase/rules-unit-testing'
import { collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, setLogLevel, Timestamp, updateDoc, where, writeBatch, GeoPoint, deleteField } from 'firebase/firestore'

// Never connect these tests to a live Firebase project, even if credentials or
// a project environment variable happen to exist on a developer machine.
const projectId = 'demo-quickfix-validation'
const host = process.env.FIRESTORE_EMULATOR_HOST
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw new Error('Start the local demo Firestore emulator; production hosts are refused')
let env
setLogLevel('silent')
const time = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'))
const future = Timestamp.fromDate(new Date(Date.now() + 86400000))
const point = new GeoPoint(33.7731, 72.3626)
const approximate = new GeoPoint(33.77, 72.36)
const user = (uid, role = 'user') => ({ fullName: `Demo ${uid}`, email: `${uid}@example.com`, phone: '', role, createdAt: time, updatedAt: time })
const worker = () => ({ fullName: 'Demo worker', email: 'worker@example.com', professions: ['plumbing'], rating: 4, reviews: 1, completedJobs: 0, isAvailable: true, createdAt: time, updatedAt: time })
const job = (status = 'open', workerId = null) => ({ userId: 'client', workerId, status, title: 'Demo work', description: 'Work described for emulator tests', category: 'plumbing', address: 'Demo exact address', location: point, budgetMin: 300, budgetMax: 300, preferredDate: future, createdAt: time, updatedAt: time })
const db = (uid, age = 0) => env.authenticatedContext(uid, { auth_time: Math.floor(Date.now() / 1000) - age }).firestore()
const ref = (database, path) => doc(database, path)
async function denied(operation) { await assert.rejects(operation, error => error.code === 'permission-denied', 'Expected authorization denial, not an unrelated SDK/setup failure') }
async function seed(records) {
  await env.withSecurityRulesDisabled(async context => {
    const database = context.firestore(); const batch = writeBatch(database)
    for (const [path, data] of Object.entries(records)) batch.set(ref(database, path), data)
    await batch.commit()
  })
}
function event(userId, type, refId) { return { userId, type, refId, title: 'Generic demo update', body: 'Open the related record.', isRead: false, createdAt: serverTimestamp() } }
function inquiry() { return { clientId: 'client', category: 'plumbing', description: 'A meaningful demo work description', images: [], location: approximate, radiusKm: 10, recipientIds: ['worker', 'worker2'], status: 'open', createdAt: serverTimestamp() } }
async function quotesOn() { await seed({ 'config/features': { quotesEnabled: true } }) }
async function seedInquiry() {
  await seed({ 'quoteRequests/inquiry': { ...inquiry(), createdAt: time }, 'quoteRequests/inquiry/private/location': { address: 'Demo exact address', location: point } })
}
function quote(workerId = 'worker', amount = 300) { return { requestId: 'inquiry', workerId, clientId: 'client', amount, amountPaisa: amount * 100, message: 'Price includes the described demo work', status: 'pending', createdAt: serverTimestamp() } }

before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { host: host.split(':')[0], port: Number(host.split(':')[1]), rules: fs.readFileSync(new URL('../../docs/firestore/firestore.rules', import.meta.url), 'utf8') } })
})
after(async () => { await env?.cleanup() })
beforeEach(async () => {
  await env.clearFirestore()
  await seed({ 'users/client': user('client'), 'users/worker': user('worker', 'worker'), 'users/worker2': user('worker2', 'worker'), 'users/stranger': user('stranger'), 'users/admin': user('admin', 'admin'), 'workers/worker': worker(), 'workers/worker2': worker(), 'jobs/job': job() })
})

test('anonymous profile reads and self-admin/verified-client escalation are denied', async () => {
  await denied(getDoc(ref(env.unauthenticatedContext().firestore(), 'users/client')))
  await denied(updateDoc(ref(db('client'), 'users/client'), { role: 'admin' }))
  await denied(updateDoc(ref(db('client'), 'users/client'), { verifiedClient: true }))
  await denied(setDoc(ref(db('new-admin'), 'users/new-admin'), user('new-admin', 'admin')))
  await assertSucceeds(updateDoc(ref(db('client'), 'users/client'), { fullName: 'Updated demo name', 'notificationPrefs.messages': false }))
})

test('private address book is owner/admin-only, with no new public exact-pin field', async () => {
  const owner = db('client')
  await assertSucceeds(setDoc(ref(owner, 'users/client/private/addressBook'), { addresses: [{ id: 'home', label: 'Demo', address: 'Private landmark', location: point }], updatedAt: serverTimestamp() }))
  await assertSucceeds(getDoc(ref(owner, 'users/client/private/addressBook')))
  await denied(getDoc(ref(db('stranger'), 'users/client/private/addressBook')))
  await denied(updateDoc(ref(owner, 'users/client'), { addresses: [{ address: 'public secret', location: point }] }))
})

test('legacy public address migration is atomic and owner-scoped', async () => {
  await seed({ 'users/client': { ...user('client'), addresses: [{ label: 'Demo', address: 'Old private landmark', location: point }] } })
  const owner = db('client'); const batch = writeBatch(owner)
  batch.set(ref(owner, 'users/client/private/addressBook'), { addresses: [{ id: 'a', label: 'Demo', address: 'Old private landmark', location: point }], updatedAt: serverTimestamp() })
  batch.update(ref(owner, 'users/client'), { addresses: deleteField() })
  await assertSucceeds(batch.commit())
  assert.equal((await getDoc(ref(owner, 'users/client'))).data().addresses, undefined)
})

test('worker trust flags and aggregate ratings cannot be forged by the owner', async () => {
  const own = db('worker')
  for (const change of [{ approved: true }, { blocked: false }, { rating: 5, reviews: 99 }, { verification: { status: 'verified' } }]) await denied(updateDoc(ref(own, 'workers/worker'), change))
  await assertSucceeds(updateDoc(ref(own, 'workers/worker'), { about: 'Self-described demo skills', isAvailable: false }))
})

test('consented verification submission atomically publishes status only', async () => {
  const own = db('worker'); const batch = writeBatch(own)
  batch.set(ref(own, 'workerVerifications/worker'), { status: 'pending', cnicFrontPath: '/demo/front', cnicBackPath: '/demo/back', selfiePath: '/demo/selfie', consent: true, consentVersion: '2026-10-local-demo-v1', submittedAt: serverTimestamp() })
  batch.update(ref(own, 'workers/worker'), { verification: { status: 'pending', submittedAt: serverTimestamp() }, updatedAt: serverTimestamp() })
  await assertSucceeds(batch.commit())
  await denied(getDoc(ref(db('stranger'), 'workerVerifications/worker')))
  await denied(updateDoc(ref(own, 'workerVerifications/worker'), { status: 'verified' }))
  await assertSucceeds(getDoc(ref(own, 'workerVerifications/worker')))
})

test('only client assigns; assigned worker progresses without rewriting ownership/budget', async () => {
  await denied(updateDoc(ref(db('worker'), 'jobs/job'), { workerId: 'worker', status: 'assigned', assignedAt: time, updatedAt: time }))
  await denied(updateDoc(ref(db('stranger'), 'jobs/job'), { workerId: 'stranger', status: 'assigned' }))
  await assertSucceeds(updateDoc(ref(db('client'), 'jobs/job'), { workerId: 'worker', status: 'assigned', assignedAt: time, updatedAt: time }))
  await denied(updateDoc(ref(db('client'), 'jobs/job'), { status: 'completed', completedAt: time }))
  await assertSucceeds(updateDoc(ref(db('worker'), 'jobs/job'), { status: 'inProgress', updatedAt: time }))
  await denied(updateDoc(ref(db('worker'), 'jobs/job'), { status: 'completed', budgetMax: 999, completedAt: time }))
  await assertSucceeds(updateDoc(ref(db('worker'), 'jobs/job'), { status: 'completed', completedAt: time, updatedAt: time }))
})

test('owning client can reschedule/cancel active work, not rewrite completed history', async () => {
  await seed({ 'jobs/job': job('inProgress', 'worker') })
  await assertSucceeds(updateDoc(ref(db('client'), 'jobs/job'), { preferredDate: future, preferredTime: future, updatedAt: serverTimestamp() }))
  await assertSucceeds(updateDoc(ref(db('client'), 'jobs/job'), { status: 'cancelled', cancelReason: 'Schedule conflict', cancelledAt: serverTimestamp(), updatedAt: serverTimestamp() }))
  await denied(updateDoc(ref(db('client'), 'jobs/job'), { status: 'open', workerId: null }))
})

test('missing private chat parent can bootstrap; first parent/message commit is participant-private', async () => {
  const owner = db('client'); assert.equal((await getDoc(ref(owner, 'conversations/client_worker'))).exists(), false)
  const batch = writeBatch(owner)
  batch.set(ref(owner, 'conversations/client_worker'), { participants: ['client', 'worker'], lastMessage: 'Hello', lastMessageAt: time, lastSenderId: 'client', unreadCount: 1 })
  batch.set(ref(owner, 'conversations/client_worker/messages/first'), { senderId: 'client', receiverId: 'worker', text: 'Hello', isRead: false, createdAt: time })
  await assertSucceeds(batch.commit())
  await denied(getDoc(ref(db('stranger'), 'conversations/client_worker')))
  await denied(getDocs(collection(db('stranger'), 'conversations/client_worker/messages')))
  await assertSucceeds(getDocs(collection(db('worker'), 'conversations/client_worker/messages')))
  await denied(updateDoc(ref(db('worker'), 'conversations/client_worker'), { participants: ['worker', 'stranger'] }))
})

test('only receiver can mark read, no participant may rewrite message text', async () => {
  await seed({ 'conversations/client_worker': { participants: ['client', 'worker'] }, 'conversations/client_worker/messages/m': { senderId: 'client', receiverId: 'worker', text: 'Demo', isRead: false, createdAt: time } })
  await denied(updateDoc(ref(db('client'), 'conversations/client_worker/messages/m'), { isRead: true }))
  await denied(updateDoc(ref(db('worker'), 'conversations/client_worker/messages/m'), { text: 'Changed' }))
  await assertSucceeds(updateDoc(ref(db('worker'), 'conversations/client_worker/messages/m'), { isRead: true }))
})

test('pending withdrawal hides applicant history from acceptance; owner selection is atomic', async () => {
  await seed({ 'jobRequests/request': { jobId: 'job', workerId: 'worker', userId: 'client', status: 'pending', createdAt: time } })
  await assertSucceeds(updateDoc(ref(db('worker'), 'jobRequests/request'), { status: 'withdrawn', respondedAt: serverTimestamp() }))
  const client = db('client'); const batch = writeBatch(client)
  batch.update(ref(client, 'jobs/job'), { status: 'assigned', workerId: 'worker', assignedAt: time, updatedAt: time })
  batch.update(ref(client, 'jobRequests/request'), { status: 'accepted', respondedAt: time })
  await denied(batch.commit())
  await seed({ 'jobRequests/request': { jobId: 'job', workerId: 'worker', userId: 'client', status: 'pending', createdAt: time } })
  const accept = writeBatch(client)
  accept.update(ref(client, 'jobs/job'), { status: 'assigned', workerId: 'worker', assignedAt: time, updatedAt: time })
  accept.update(ref(client, 'jobRequests/request'), { status: 'accepted', respondedAt: time })
  await assertSucceeds(accept.commit())
  await denied(updateDoc(ref(db('worker'), 'jobRequests/request'), { status: 'withdrawn', respondedAt: time }))
})

test('weighted rating addition proves a fresh completed-job review in the same commit', async () => {
  await seed({ 'jobs/job': job('completed', 'worker') })
  const client = db('client'); const batch = writeBatch(client)
  batch.set(ref(client, 'reviews/review'), { jobId: 'job', reviewerId: 'client', workerId: 'worker', rating: 5, originalText: 'Demo review', originalLang: 'und', createdAt: time })
  batch.update(ref(client, 'workers/worker'), { rating: 4.5, reviews: 2, ratingReviewId: 'review', updatedAt: time })
  await assertSucceeds(batch.commit())
  await denied(updateDoc(ref(client, 'workers/worker'), { rating: 4.6666667, reviews: 3, ratingReviewId: 'review' }))
})

test('receipts/reports are scoped; notifications are receiver-only with immutable content', async () => {
  await seed({ 'jobs/job': job('completed', 'worker'), 'payments/payment': { jobId: 'job', payerId: 'client', workerId: 'worker', amount: 300, status: 'paid', method: 'mock', createdAt: time }, 'reports/report': { reporterId: 'client', reportedId: 'worker', reason: 'Demo', status: 'open', createdAt: time } })
  await assertSucceeds(getDoc(ref(db('worker'), 'payments/payment')))
  await denied(getDoc(ref(db('stranger'), 'payments/payment')))
  await denied(getDoc(ref(db('worker'), 'reports/report')))
  await assertSucceeds(getDoc(ref(db('admin'), 'reports/report')))
  await assertSucceeds(setDoc(ref(db('client'), 'notifications/notice'), event('worker', 'payment', 'payment')))
  await denied(getDoc(ref(db('client'), 'notifications/notice')))
  await assertSucceeds(getDoc(ref(db('worker'), 'notifications/notice')))
  await denied(updateDoc(ref(db('worker'), 'notifications/notice'), { title: 'Forged' }))
  await assertSucceeds(updateDoc(ref(db('worker'), 'notifications/notice'), { isRead: true }))
})

test('payout create requires atomic owner-private revision; references never belong on public profile', async () => {
  const own = db('worker'); const batch = writeBatch(own)
  const payout = { workerId: 'worker', amount: 250, amountPaisa: 25000, method: 'bank', accountRef: 'DEMO-ACCOUNT', status: 'pending', createdAt: serverTimestamp() }
  await denied(setDoc(ref(own, 'payouts/without-revision'), payout))
  batch.set(ref(own, 'payouts/request'), payout)
  batch.set(ref(own, 'workers/worker/private/payout'), { revision: 1, lastPayoutId: 'request', method: 'bank', accountRef: 'DEMO-ACCOUNT' })
  batch.update(ref(own, 'workers/worker'), { payoutMethod: { type: 'bank' } })
  await assertSucceeds(batch.commit())
  await denied(getDoc(ref(db('stranger'), 'payouts/request')))
  await denied(getDoc(ref(db('client'), 'workers/worker/private/payout')))
  await denied(updateDoc(ref(own, 'workers/worker'), { payoutMethod: { type: 'bank', accountRef: 'public-secret' } }))
  await denied(updateDoc(ref(own, 'payouts/request'), { status: 'paid' }))
})

test('fresh-auth deletion pause blocks assignment, new chats and stale profile recreation', async () => {
  const workerDb = db('worker')
  await denied(setDoc(ref(db('worker2', 3600), 'accountDeletions/worker2'), { state: 'checking', startedAt: serverTimestamp() }))
  await assertSucceeds(setDoc(ref(workerDb, 'accountDeletions/worker'), { state: 'checking', startedAt: serverTimestamp() }))
  await denied(updateDoc(ref(db('client'), 'jobs/job'), { workerId: 'worker', status: 'assigned', assignedAt: time, updatedAt: time }))
  await denied(setDoc(ref(db('client'), 'conversations/client_worker'), { participants: ['client', 'worker'] }))
  await assertSucceeds(updateDoc(ref(workerDb, 'accountDeletions/worker'), { state: 'cleaning', updatedAt: serverTimestamp() }))
  const cleanup = writeBatch(workerDb)
  cleanup.delete(ref(workerDb, 'workers/worker')); cleanup.delete(ref(workerDb, 'users/worker'))
  cleanup.update(ref(workerDb, 'accountDeletions/worker'), { state: 'authPending', updatedAt: serverTimestamp() })
  await assertSucceeds(cleanup.commit())
  await denied(setDoc(ref(workerDb, 'users/worker'), user('worker', 'worker')))
  await denied(deleteDoc(ref(workerDb, 'accountDeletions/worker')))
})

test('completed-history erasure preserves counterparty/financial fields only', async () => {
  await seed({ 'jobs/job': { ...job('completed', 'worker'), unknownPrivateField: 'must disappear' }, 'accountDeletions/client': { state: 'cleaning', startedAt: time } })
  const client = db('client')
  await denied(deleteDoc(ref(client, 'jobs/job')))
  await assertSucceeds(setDoc(ref(client, 'jobs/job'), { userId: 'deleted-account', workerId: 'worker', title: 'Completed job', status: 'completed', anonymized: true, category: 'plumbing', budgetMin: 300, budgetMax: 300, preferredDate: future, createdAt: time, updatedAt: time }))
  assert.equal((await getDoc(ref(db('worker'), 'jobs/job'))).data().unknownPrivateField, undefined)
})

test('quote gate defaults OFF and cannot be enabled by an ordinary client', async () => {
  await denied(setDoc(ref(db('client'), 'config/features'), { quotesEnabled: true }))
  await denied(setDoc(ref(db('client'), 'quoteRequests/inquiry'), inquiry()))
})

test('quote create/invites are atomic; exact pin is private before booking', async () => {
  await quotesOn(); const client = db('client'); const batch = writeBatch(client)
  batch.set(ref(client, 'quoteRequests/inquiry'), inquiry())
  batch.set(ref(client, 'quoteRequests/inquiry/private/location'), { address: 'Demo exact address', location: point })
  for (const workerId of ['worker', 'worker2']) batch.set(ref(client, `notifications/invite-${workerId}`), event(workerId, 'quote', 'inquiry'))
  await assertSucceeds(batch.commit())
  const publicInquiry = (await getDoc(ref(db('stranger'), 'quoteRequests/inquiry'))).data()
  assert.equal(publicInquiry.address, undefined); assert.equal(publicInquiry.location.latitude, approximate.latitude)
  await denied(getDoc(ref(db('worker'), 'quoteRequests/inquiry/private/location')))
  await assertSucceeds(getDoc(ref(client, 'quoteRequests/inquiry/private/location')))
})

test('only invited workers quote; price/message private to worker/client/admin', async () => {
  await quotesOn(); await seedInquiry()
  await assertSucceeds(setDoc(ref(db('worker'), 'quotes/quote'), quote()))
  await denied(setDoc(ref(db('stranger'), 'quotes/intruder'), quote('stranger')))
  await denied(getDoc(ref(db('worker2'), 'quotes/quote')))
  await assertSucceeds(getDocs(query(collection(db('client'), 'quotes'), where('requestId', '==', 'inquiry'))))
  await denied(updateDoc(ref(db('worker'), 'quotes/quote'), { amount: 1, amountPaisa: 100 }))
})

test('quote acceptance books exactly one selected-price job and reveals exact pin only to selected worker', async () => {
  await quotesOn(); await seedInquiry(); await seed({ 'quotes/quote': { ...quote(), createdAt: time } })
  const client = db('client'); const batch = writeBatch(client)
  batch.set(ref(client, 'jobs/booked'), { ...job('assigned', 'worker'), quoteRequestId: 'inquiry', quoteId: 'quote', assignedAt: time })
  batch.update(ref(client, 'quoteRequests/inquiry'), { status: 'accepted', acceptedQuoteId: 'quote', acceptedWorkerId: 'worker', jobId: 'booked', updatedAt: serverTimestamp() })
  batch.update(ref(client, 'quotes/quote'), { status: 'accepted' })
  batch.set(ref(client, 'notifications/booked'), event('worker', 'job', 'booked'))
  await assertSucceeds(batch.commit())
  await assertSucceeds(getDoc(ref(db('worker'), 'quoteRequests/inquiry/private/location')))
  await denied(getDoc(ref(db('worker2'), 'quoteRequests/inquiry/private/location')))
  await denied(setDoc(ref(client, 'jobs/second'), { ...job('assigned', 'worker'), quoteRequestId: 'inquiry', quoteId: 'quote', assignedAt: time }))
})

test('dispute/case/report links are bidirectional and unlinked/unrelated reports cannot close another case', async () => {
  await seed({ 'jobs/job': job('completed', 'worker') }); const client = db('client')
  const dispute = { jobId: 'job', raisedBy: 'client', againstId: 'worker', category: 'Poor quality', description: 'Meaningful details for the emulator case', expectedResolution: 'Redo the work', images: [], status: 'open', createdAt: serverTimestamp(), reportId: 'linked' }
  await denied(setDoc(ref(client, 'disputes/job'), dispute))
  const batch = writeBatch(client)
  batch.set(ref(client, 'disputes/job'), dispute)
  batch.set(ref(client, 'reports/linked'), { reporterId: 'client', reportedId: 'worker', jobId: 'job', disputeId: 'job', reason: 'Dispute: Poor quality', details: 'Demo details', status: 'open', createdAt: serverTimestamp() })
  batch.set(ref(client, 'notifications/dispute'), event('worker', 'dispute', 'job'))
  await assertSucceeds(batch.commit())
  await denied(getDoc(ref(db('stranger'), 'disputes/job')))
  await assertSucceeds(getDoc(ref(db('worker'), 'disputes/job')))
  await denied(setDoc(ref(client, 'reports/duplicate'), { reporterId: 'client', reportedId: 'worker', jobId: 'job', disputeId: 'job', reason: 'Forged link', status: 'open', createdAt: serverTimestamp() }))
})

test('competing selection and withdrawal have one atomic winner', async () => {
  await seed({ 'jobRequests/race': { jobId: 'job', workerId: 'worker', userId: 'client', status: 'pending', createdAt: time } })
  const client = db('client'), workerDb = db('worker')
  const accept = writeBatch(client), withdraw = writeBatch(workerDb)
  accept.update(ref(client, 'jobs/job'), { status: 'assigned', workerId: 'worker', assignedAt: time, updatedAt: time })
  accept.update(ref(client, 'jobRequests/race'), { status: 'accepted', respondedAt: time })
  withdraw.update(ref(workerDb, 'jobRequests/race'), { status: 'withdrawn', respondedAt: serverTimestamp() })
  const results = await Promise.allSettled([accept.commit(), withdraw.commit()])
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1)
  assert.equal(results.find(result => result.status === 'rejected').reason.code, 'permission-denied')
  const application = (await getDoc(ref(client, 'jobRequests/race'))).data()
  const booking = (await getDoc(ref(client, 'jobs/job'))).data()
  assert.ok((application.status === 'accepted' && booking.status === 'assigned') || (application.status === 'withdrawn' && booking.status === 'open'))
})

test('two quote accept batches cannot create two bookings for one inquiry', async () => {
  await quotesOn(); await seedInquiry()
  await seed({ 'quotes/choice-a': { ...quote('worker'), createdAt: time }, 'quotes/choice-b': { ...quote('worker2'), createdAt: time } })
  const client = db('client')
  const booking = (id, workerId, quoteId) => {
    const batch = writeBatch(client)
    batch.set(ref(client, `jobs/${id}`), { ...job('assigned', workerId), quoteRequestId: 'inquiry', quoteId, assignedAt: time })
    batch.update(ref(client, 'quoteRequests/inquiry'), { status: 'accepted', acceptedQuoteId: quoteId, acceptedWorkerId: workerId, jobId: id, updatedAt: serverTimestamp() })
    batch.update(ref(client, `quotes/${quoteId}`), { status: 'accepted' })
    return batch.commit()
  }
  const results = await Promise.allSettled([booking('race-a', 'worker', 'choice-a'), booking('race-b', 'worker2', 'choice-b')])
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1)
  assert.equal(results.find(result => result.status === 'rejected').reason.code, 'permission-denied')
  const jobs = await getDocs(query(collection(client, 'jobs'), where('quoteRequestId', '==', 'inquiry')))
  assert.equal(jobs.size, 1)
})

test('stale payout revision cannot reserve two requests concurrently', async () => {
  const owner = db('worker')
  const reserve = id => {
    const batch = writeBatch(owner)
    batch.set(ref(owner, `payouts/${id}`), { workerId: 'worker', amount: 700, amountPaisa: 70000, method: 'bank', accountRef: 'DEMO', status: 'pending', createdAt: serverTimestamp() })
    batch.set(ref(owner, 'workers/worker/private/payout'), { revision: 1, lastPayoutId: id, method: 'bank', accountRef: 'DEMO' })
    return batch.commit()
  }
  const results = await Promise.allSettled([reserve('one'), reserve('two')])
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1)
  assert.equal(results.find(result => result.status === 'rejected').reason.code, 'permission-denied')
})

test('payout erasure removes account references without changing amount/status', async () => {
  await seed({ 'payouts/old': { workerId: 'worker', amount: 12.34, amountPaisa: 1234, method: 'bank', accountRef: 'PRIVATE-DEMO', status: 'pending', createdAt: time }, 'accountDeletions/worker': { state: 'cleaning', startedAt: time } })
  const own = db('worker')
  await denied(setDoc(ref(own, 'payouts/old'), { workerId: 'deleted-account', anonymized: true, amount: 99, amountPaisa: 9900, method: 'bank', status: 'pending', createdAt: time }))
  await assertSucceeds(setDoc(ref(own, 'payouts/old'), { workerId: 'deleted-account', anonymized: true, amount: 12.34, amountPaisa: 1234, method: 'bank', status: 'pending', createdAt: time }))
  assert.equal((await getDoc(ref(db('admin'), 'payouts/old'))).data().accountRef, undefined)
})
