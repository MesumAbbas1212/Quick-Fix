// Provision an administrator account: Firebase Auth user + users/{uid} with role=admin.
//
// Dry run by default. A service account and --write are required to persist.
//
//   GOOGLE_APPLICATION_CREDENTIALS=path/to/key.json \
//     node create-admin.js --email admin2@quickfix.test --password 'Str0ng@Pass' --name 'Second Admin'
//
// Add --write to actually create it. The app can never do this itself: the `users`
// create rule permits only role in ['user','worker'], so admins are provisioned out of
// band by design.
'use strict'

function parseArgs(argv) {
  const args = { write: false }
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i]
    if (token === '--write') { args.write = true; continue }
    if (!token.startsWith('--')) throw new Error(`Unexpected argument: ${token}`)
    const key = token.slice(2)
    const value = argv[i + 1]
    if (value === undefined || value.startsWith('--')) throw new Error(`Missing value for --${key}`)
    args[key] = value
    i++
  }
  return args
}

function validate({ email, password, name }) {
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('A valid --email is required.')
  if (!name || !name.trim()) throw new Error('A --name is required (it is shown in the app).')
  if (!password || password.length < 8) throw new Error('A --password of at least 8 characters is required.')
  return { email: email.trim().toLowerCase(), password, name: name.trim() }
}

async function run({ email, password, name, phone, write }) {
  const plan = { mode: write ? 'write' : 'dry-run', email, name, role: 'admin', phone: phone || null }
  if (!write) {
    console.log(JSON.stringify({ ...plan, note: 'No changes made. Re-run with --write to provision.' }, null, 2))
    return plan
  }
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('Refusing --write: set GOOGLE_APPLICATION_CREDENTIALS to an authorized service-account JSON file.')
  }

  const admin = require('firebase-admin')
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.applicationDefault() })
  const db = admin.firestore()

  let uid
  let created = false
  try {
    uid = (await admin.auth().getUserByEmail(email)).uid
  } catch {
    uid = (await admin.auth().createUser({ email, password, displayName: name })).uid
    created = true
  }

  const ref = db.collection('users').doc(uid)
  const existing = await ref.get()
  const now = admin.firestore.Timestamp.now()
  await ref.set(
    {
      email,
      fullName: name,
      phone: phone || '',
      role: 'admin',
      // Never rewrite createdAt on an existing account: it orders every admin query.
      ...(existing.exists ? {} : { createdAt: now }),
      updatedAt: now,
    },
    { merge: true },
  )

  const result = {
    ...plan,
    uid,
    authUser: created ? 'created' : 'existing account reused',
    profile: existing.exists ? 'merged (role set to admin)' : 'created',
    liveWritesPerformed: true,
  }
  console.log(JSON.stringify(result, null, 2))
  return result
}

if (require.main === module) {
  try {
    const args = parseArgs(process.argv.slice(2))
    const input = validate(args)
    run({ ...input, phone: args.phone, write: args.write }).catch((error) => {
      console.error(`Create admin failed: ${error.message}`)
      process.exitCode = 1
    })
  } catch (error) {
    console.error(`Create admin failed: ${error.message}`)
    process.exitCode = 1
  }
}

module.exports = { parseArgs, validate, run }
