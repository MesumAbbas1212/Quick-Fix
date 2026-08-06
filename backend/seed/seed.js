// Firestore seed script for QuickFix demo data.
// Usage: GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json node seed.js
// Requires firebase-admin: npm install firebase-admin in this directory.
const admin = require('firebase-admin')

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
})

const db = admin.firestore()

const CATEGORIES = [
  ['cleaning', 'Cleaning', 'Home deep cleaning & janitorial services'],
  ['plumbing', 'Plumbing', 'Leaks, pipes, faucets and water systems'],
  ['electrical', 'Electrical', 'Wiring, fans, switches and electrical repair'],
  ['carpentry', 'Carpentry', 'Furniture repair, cabinets and woodwork'],
  ['painting', 'Painting', 'Interior and exterior painting services'],
  ['gardening', 'Gardening', 'Lawn care, trimming and garden upkeep'],
  ['moving', 'Moving', 'Home and office shifting assistance'],
  ['applianceRepair', 'Appliance Repair', 'AC, fridge, washing machine and more'],
]

const CITIES = [
  [31.5497, 74.3436, 'Lahore'],
  [31.5204, 74.3587, 'Gulberg, Lahore'],
  [31.4504, 74.2669, 'DHA Phase 5, Lahore'],
  [33.6844, 73.0479, 'Islamabad'],
  [33.5651, 73.0169, 'Rawalpindi'],
  [31.582, 74.3292, 'Model Town, Lahore'],
]

const NAMES = [
  'Ahmed Raza', 'Bilal Khan', 'Usman Ali', 'Hamza Sheikh', 'Faisal Mehmood',
  'Sara Ahmed', 'Ayesha Siddiqui', 'Fatima Noor', 'Ali Hassan', 'Zain Malik',
  'Hira Shah', 'Omar Farooq',
]

function rand(min, max) {
  return min + Math.random() * (max - min)
}

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)]
}

const PROFESSIONS = Object.keys({
  cleaning: 1, plumbing: 1, electrical: 1, carpentry: 1, painting: 1,
  gardening: 1, moving: 1, applianceRepair: 1,
})

async function seed() {
  const ts = admin.firestore.Timestamp.now()

  for (const [id, name, description] of CATEGORIES) {
    await db.collection('categories').doc(id).set({
      name,
      description,
      iconPath: `assets/categories/${id}.png`,
      createdAt: ts,
    })
  }
  console.log('Seeded categories')

  const workers = []
  for (let i = 0; i < 8; i++) {
    const [lat, lng, city] = CITIES[i % CITIES.length]
    const uid = `worker-${i + 1}`
    workers.push(uid)
    await db.collection('users').doc(uid).set({
      fullName: NAMES[i],
      email: `worker${i + 1}@quickfix.test`,
      phone: `0300${String(1000000 + i * 11111)}`,
      role: 'worker',
      createdAt: ts,
      updatedAt: ts,
    })
    await db.collection('workers').doc(uid).set({
      uid,
      fullName: NAMES[i],
      email: `worker${i + 1}@quickfix.test`,
      phone: `0300${String(1000000 + i * 11111)}`,
      professions: [PROFESSIONS[i % PROFESSIONS.length], PROFESSIONS[(i + 3) % PROFESSIONS.length]],
      location: new admin.firestore.GeoPoint(lat + rand(-0.02, 0.02), lng + rand(-0.02, 0.02)),
      city,
      minBudget: Math.round(rand(800, 1500)),
      maxBudget: Math.round(rand(3000, 6000)),
      rating: rand(3.5, 5.0),
      completedJobs: Math.floor(rand(3, 40)),
      isAvailable: true,
      approved: true,
      blocked: false,
      createdAt: ts,
      updatedAt: ts,
    })
  }
  console.log('Seeded 8 workers')

  for (let i = 0; i < 4; i++) {
    const uid = `user-${i + 1}`
    await db.collection('users').doc(uid).set({
      fullName: NAMES[8 + i],
      email: `user${i + 1}@quickfix.test`,
      phone: `0321${String(2000000 + i * 22222)}`,
      role: 'user',
      createdAt: ts,
      updatedAt: ts,
    })
  }
  console.log('Seeded 4 users')

  const jobTitles = {
    plumbing: 'Kitchen sink leaking', electrical: 'Fan not working',
    cleaning: 'Apartment deep clean', applianceRepair: 'AC not cooling',
    carpentry: 'Wardrobe repair', painting: 'Bedroom repaint',
    gardening: 'Lawn trimming', moving: 'Home shifting help',
  }

  for (let i = 0; i < 15; i++) {
    const cat = PROFESSIONS[i % PROFESSIONS.length]
    const [lat, lng, city] = CITIES[i % CITIES.length]
    const status = i < 5 ? 'open' : i < 10 ? 'assigned' : 'completed'
    const assigned = i < 5 ? null : workers[i % workers.length]
    const doc = {
      userId: `user-${(i % 4) + 1}`,
      workerId: assigned,
      title: jobTitles[cat],
      description: 'Urgent home service needed. Please contact for details.',
      category: cat,
      address: city,
      location: new admin.firestore.GeoPoint(lat + rand(-0.01, 0.01), lng + rand(-0.01, 0.01)),
      budgetMin: Math.round(rand(1000, 2000)),
      budgetMax: Math.round(rand(2500, 5000)),
      preferredDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + i * 86400000)),
      status,
      rating: status === 'completed' ? rand(3.5, 5) : null,
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - i * 3600000)),
      updatedAt: ts,
      assignedAt: assigned ? ts : null,
      completedAt: status === 'completed' ? ts : null,
    }
    await db.collection('jobs').add(doc)
  }
  console.log('Seeded 15 jobs')

  const convId = 'user-1_worker-1'
  const msgs = [
    'Hi, I need help with AC repair',
    'Yes sure, when do you need it?',
    'Tomorrow morning works',
    'Great, I will be there at 10 AM',
  ]
  for (let i = 0; i < msgs.length; i++) {
    await db.collection('conversations').doc(convId).collection('messages').add({
      senderId: i % 2 === 0 ? 'user-1' : 'worker-1',
      receiverId: i % 2 === 0 ? 'worker-1' : 'user-1',
      text: msgs[i],
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - (4 - i) * 3600000)),
      read: true,
    })
  }
  await db.collection('conversations').doc(convId).set({
    participants: ['user-1', 'worker-1'],
    lastMessage: 'Great, I will be there at 10 AM',
    lastMessageAt: ts,
  })
  console.log('Seeded sample conversation')

  const reviews = [
    ['بہت اچھا کام، وقت پر مکمل کیا', 'Very good work, completed on time.', 5],
    ['مناسب قیمت اور پیشہ ورانہ رویہ', 'Fair price and professional attitude.', 4.5],
    ['Great electrician, highly recommended!', '', 5],
    ['کام اچھا تھا لیکن تھوڑا دیر سے آیا', 'Good work but arrived a bit late.', 4],
  ]
  for (let i = 0; i < reviews.length; i++) {
    const [original, translated, rating] = reviews[i]
    await db.collection('reviews').add({
      jobId: `seed-job-${i + 1}`,
      reviewerId: `user-${(i % 4) + 1}`,
      workerId: `worker-${(i % 8) + 1}`,
      rating,
      originalText: original,
      originalLang: 'ur',
      translatedText: translated || null,
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - i * 86400000)),
    })
  }
  console.log('Seeded 4 reviews')

  console.log('Seed complete')
}

seed()
  .catch((err) => {
    console.error('Seed failed:', err)
    process.exit(1)
  })
