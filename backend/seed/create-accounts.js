const admin = require('firebase-admin')
const fs = require('fs')

const sa = JSON.parse(fs.readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'))
admin.initializeApp({ credential: admin.credential.cert(sa) })
const db = admin.firestore()

// Create Auth accounts + Firestore profiles for demo logins.
// OVERRIDE_PASSWORD: use if you want a custom password, else defaults below.
const accounts = [
  {
    email: 'admin@quickfix.test',
    password: process.env.OVERRIDE_PASSWORD || 'Admin@123',
    fullName: 'Mesum Admin',
    phone: '03001234000',
    role: 'admin',
    firestoreId: 'admin-1',
  },
  {
    email: 'user@quickfix.test',
    password: process.env.OVERRIDE_PASSWORD || 'User@123',
    fullName: 'Sara Ahmed',
    phone: '03001234001',
    role: 'user',
    firestoreId: 'user-1',
  },
  {
    email: 'worker@quickfix.test',
    password: process.env.OVERRIDE_PASSWORD || 'Worker@123',
    fullName: 'Ahmed Raza',
    phone: '03001234002',
    role: 'worker',
    firestoreId: 'worker-1',
  },
]

async function main() {
  for (const acc of accounts) {
    let uid = acc.firestoreId
    try {
      const existing = await admin.auth().getUserByEmail(acc.email)
      uid = existing.uid
      console.log(`${acc.email} already exists (${uid}), skipping create`)
    } catch {
      const created = await admin.auth().createUser({
        email: acc.email,
        password: acc.password,
        displayName: acc.fullName,
      })
      uid = created.uid
      console.log(`Created auth account ${acc.email} -> ${uid}`)
    }
    await db.collection('users').doc(uid).set(
      {
        email: acc.email,
        fullName: acc.fullName,
        phone: acc.phone,
        role: acc.role,
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      },
      { merge: true },
    )
    console.log(`Profile upserted for ${acc.email} (role=${acc.role})`)
  }
  console.log('Done. Test logins: admin@quickfix.test / Admin@123 etc.')
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })