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

// Cities across Pakistan - heavy coverage of Attock (project home district)
// plus major cities of every province.
const CITIES = [
  // Attock district (extensive coverage)
  [33.7731, 72.3626, 'Attock City'],
  [33.8609, 72.2397, 'Hassan Abdal'],
  [33.9058, 72.4392, 'Hazro'],
  [33.7585, 72.3745, 'Kamra'],
  [33.8700, 72.2400, 'Burhan'],
  [33.7100, 72.4300, 'Pindi Gheb'],
  [33.6900, 72.5900, 'Fateh Jang'],
  [33.6400, 72.3600, 'Jand'],
  [33.5500, 72.5700, 'Talagang Road, Attock'],
  // Punjab
  [31.5497, 74.3436, 'Lahore'],
  [31.5204, 74.3587, 'Gulberg, Lahore'],
  [31.4504, 74.2669, 'DHA Phase 5, Lahore'],
  [31.582, 74.3292, 'Model Town, Lahore'],
  [30.1575, 71.5249, 'Multan'],
  [31.4187, 73.0791, 'Faisalabad'],
  [32.074, 72.6602, 'Sargodha'],
  [30.1798, 71.4925, 'Bahawalpur'],
  [30.7046, 72.6546, 'Vehari'],
  [29.3956, 71.6602, 'Rahim Yar Khan'],
  [31.0291, 71.4431, 'Khanewal'],
  [32.3266, 71.3365, 'Mianwali'],
  [32.9403, 71.4669, 'Khushab'],
  [30.8427, 73.4031, 'Okara'],
  [30.8122, 73.9776, 'Sahiwal'],
  [31.2163, 72.4242, 'Jhang'],
  [30.3572, 71.4897, 'Muzaffargarh'],
  // Islamabad / Rawalpindi
  [33.6844, 73.0479, 'Islamabad'],
  [33.5651, 73.0169, 'Rawalpindi'],
  [33.5181, 73.0873, 'Bahria Town, Rawalpindi'],
  [33.7380, 73.0843, 'Bani Gala, Islamabad'],
  // Khyber Pakhtunkhwa
  [34.0151, 71.5249, 'Peshawar'],
  [34.1474, 72.6062, 'Mardan'],
  [34.1905, 72.0447, 'Nowshera'],
  [34.5195, 69.2075, 'Kohat'],
  [35.2205, 68.4239, 'Abbottabad'],
  [34.8816, 72.3867, 'Buner'],
  [34.3782, 72.9494, 'Swabi'],
  [35.9208, 74.3144, 'Gilgit'],
  [35.3212, 75.3674, 'Skardu'],
  // Sindh
  [24.8607, 67.0011, 'Karachi'],
  [24.9425, 67.1451, 'Gulshan-e-Iqbal, Karachi'],
  [25.3792, 68.3666, 'Hyderabad'],
  [27.5590, 68.7824, 'Sukkur'],
  [26.2428, 68.6676, 'Nawabshah'],
  [25.3647, 68.3883, 'Jamshoro'],
  [28.0218, 68.7998, 'Shikarpur'],
  // Balochistan
  [30.1798, 66.9749, 'Quetta'],
  [25.1215, 62.3262, 'Gwadar'],
  [29.5333, 66.9406, 'Mastung'],
  [28.4907, 65.1074, 'Kalat'],
  [30.2039, 67.0219, 'Pishin'],
  // Azad Kashmir
  [34.3601, 73.4495, 'Muzaffarabad'],
  [34.3616, 73.4616, 'Mirpur, AJK'],
]

// Worker names drawn from all over Pakistan
const WORKER_NAMES = [
  // Attock locals
  'Ahmed Raza', 'Bilal Khan', 'Usman Ali', 'Hamza Sheikh', 'Faisal Mehmood',
  'Kamran Abbasi', 'Shahid Iqbal', 'Nasir Awan',
  // Punjab
  'Ali Hassan', 'Zain Malik', 'Omar Farooq', 'Tariq Mehmood', 'Rana Sana',
  'Shehbaz Gondal', 'Adnan Chaudhry', 'Waqar Bhatti', 'Saqib Joya',
  'Imran Gujjar', 'Yasir Lodhi',
  // KP + North
  'Gul Zaman', 'Rehmat Khan', 'Ihsanullah', 'Noor Alam', 'Sohail Khan',
  'Fazal Karim', 'Zubair Toru', 'Ajmal Shah',
  // Sindh
  'Sanaullah Memon', 'Rashid Soomro', 'Ali Raza Qureshi', 'Kashif Shaikh',
  'Danish Baloch', 'Farhan Siddiqui',
  // Balochistan
  'Abdul Rehman Bugti', 'Hameed Mengal', 'Saif Rakhshani',
  // AJK / GB
  'Tanveer Abbasi', 'Mudassar Mirza', 'Shabbir Hussain',
  // Female professionals
  'Sara Ahmed', 'Ayesha Siddiqui', 'Fatima Noor', 'Hira Shah', 'Nimra Aslam',
  'Mahnoor Fatima', 'Zubaida Bibi', 'Kausar Parveen',
]

const USER_NAMES = [
  'Ahmed Ali', 'Bilal Hussain', 'Sana Javed', 'Umar Draz', 'Rida Khan',
  'Hamna Tariq', 'Junaid Akmal', 'Areeba Malik', 'Usman Ghani', 'Mehak Noor',
  'Saad Rehman', 'Aqib Chohan', 'Fizza Batool', 'Hassan Javed', 'Iqra Sheikh',
  'Danish Ali', 'Noor Fatima', 'Shahzar Khan', 'Amna Riaz', 'Waleed Anwar',
  'Bushra Kanwal', 'Talha Munir', 'Zoya Hussain', 'Faizan Rasool',
  'Mariam Nawaz',
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

const ABOUT_TEMPLATES = [
  '{years} years of experience in {profession}. Hardworking and always on time.',
  'Certified {profession} specialist serving {city} and nearby areas.',
  'Reliable {profession} expert. Quality work at fair prices.',
  'Full-time {profession} professional. Available 7 days a week.',
  'Skilled in {profession} with {years}+ years of hands-on experience.',
]

const LANGUAGES = [
  ['Urdu', 'English'],
  ['Urdu', 'English', 'Punjabi'],
  ['Urdu', 'Punjabi'],
  ['Urdu', 'English', 'Pashto'],
  ['Urdu', 'Sindhi', 'English'],
  ['Urdu', 'Balochi'],
  ['Urdu', 'Hindko'],
]

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

  // ---------- WORKERS ----------
  const workers = []
  const workerCount = Math.min(WORKER_NAMES.length, 48)
  for (let i = 0; i < workerCount; i++) {
    const [lat, lng, city] = CITIES[i % CITIES.length]
    const uid = `worker-${i + 1}`
    const profession = PROFESSIONS[i % PROFESSIONS.length]
    const secondProfession = PROFESSIONS[(i + 3) % PROFESSIONS.length]
    workers.push(uid)

    const professionLabel = profession.replace(/([A-Z])/g, ' $1').toLowerCase()
    const about = pick(ABOUT_TEMPLATES)
      .replace('{years}', String(Math.floor(rand(3, 15))))
      .replace('{profession}', professionLabel)
      .replace('{city}', city)

    await db.collection('users').doc(uid).set({
      fullName: WORKER_NAMES[i],
      email: `worker${i + 1}@quickfix.test`,
      phone: `0300${String(1000000 + i * 11111)}`,
      role: 'worker',
      rating: Number(rand(3.5, 5.0).toFixed(1)),
      completedJobs: Math.floor(rand(3, 40)),
      createdAt: ts,
      updatedAt: ts,
    })
    await db.collection('workers').doc(uid).set({
      uid,
      fullName: WORKER_NAMES[i],
      email: `worker${i + 1}@quickfix.test`,
      phone: `0300${String(1000000 + i * 11111)}`,
      about,
      professions: [profession, secondProfession],
      languages: pick(LANGUAGES),
      location: new admin.firestore.GeoPoint(lat + rand(-0.02, 0.02), lng + rand(-0.02, 0.02)),
      city,
      minBudget: Math.round(rand(800, 1500)),
      maxBudget: Math.round(rand(3000, 6000)),
      rating: Number(rand(3.5, 5.0).toFixed(1)),
      completedJobs: Math.floor(rand(3, 40)),
      reviews: Math.floor(rand(2, 30)),
      isAvailable: Math.random() > 0.2,
      approved: true,
      blocked: false,
      createdAt: ts,
      updatedAt: ts,
    })
  }
  console.log(`Seeded ${workerCount} workers across ${CITIES.length} cities`)

  // ---------- USERS ----------
  const users = []
  const userCount = Math.min(USER_NAMES.length, 25)
  for (let i = 0; i < userCount; i++) {
    const uid = `user-${i + 1}`
    users.push(uid)
    await db.collection('users').doc(uid).set({
      fullName: USER_NAMES[i],
      email: `user${i + 1}@quickfix.test`,
      phone: `0321${String(2000000 + i * 22222)}`,
      role: 'user',
      createdAt: ts,
      updatedAt: ts,
    })
  }
  console.log(`Seeded ${userCount} users`)

  // ---------- JOBS ----------
  const jobTitles = {
    plumbing: 'Kitchen sink leaking', electrical: 'Fan not working',
    cleaning: 'Apartment deep clean', applianceRepair: 'AC not cooling',
    carpentry: 'Wardrobe repair', painting: 'Bedroom repaint',
    gardening: 'Lawn trimming', moving: 'Home shifting help',
  }
  const jobDescriptions = [
    'Urgent home service needed. Please contact for details.',
    'Looking for an experienced professional for this task.',
    'Need this done this week. Flexible on timing.',
    'Small job but need quality work. Tools provided if needed.',
    'Please share your quote and availability.',
  ]
  const JOB_COUNT = 40
  for (let i = 0; i < JOB_COUNT; i++) {
    const cat = PROFESSIONS[i % PROFESSIONS.length]
    const [lat, lng, city] = CITIES[i % CITIES.length]
    const r = i % 10
    const status = r < 5 ? 'open' : r < 8 ? 'assigned' : 'completed'
    const assigned = status === 'open' ? null : workers[(i * 7) % workers.length]
    const doc = {
      userId: users[i % users.length],
      workerId: assigned,
      title: jobTitles[cat],
      description: pick(jobDescriptions),
      category: cat,
      address: city,
      location: new admin.firestore.GeoPoint(lat + rand(-0.01, 0.01), lng + rand(-0.01, 0.01)),
      budgetMin: Math.round(rand(1000, 2000)),
      budgetMax: Math.round(rand(2500, 5000)),
      preferredDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + i * 86400000)),
      status,
      rating: status === 'completed' ? Number(rand(3.5, 5).toFixed(1)) : null,
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - i * 3600000)),
      updatedAt: ts,
      assignedAt: assigned ? ts : null,
      completedAt: status === 'completed' ? ts : null,
    }
    await db.collection('jobs').add(doc)
  }
  console.log(`Seeded ${JOB_COUNT} jobs`)

  // ---------- CONVERSATIONS ----------
  const convPairs = [
    ['user-1', 'worker-1'],
    ['user-2', 'worker-3'],
    ['user-3', 'worker-5'],
    ['user-4', 'worker-2'],
  ]
  for (const [u, w] of convPairs) {
    const convId = `${u}_${w}`.split('_').sort().join('_')
    const msgs = [
      'Hi, I need help with AC repair',
      'Yes sure, when do you need it?',
      'Tomorrow morning works',
      'Great, I will be there at 10 AM',
    ]
    for (let i = 0; i < msgs.length; i++) {
      await db.collection('conversations').doc(convId).collection('messages').add({
        senderId: i % 2 === 0 ? u : w,
        receiverId: i % 2 === 0 ? w : u,
        text: msgs[i],
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - (4 - i) * 3600000)),
        read: true,
        isRead: true,
      })
    }
    await db.collection('conversations').doc(convId).set({
      participants: [u, w],
      lastMessage: 'Great, I will be there at 10 AM',
      lastMessageAt: ts,
      lastSenderId: w,
      unreadCount: 0,
    })
  }
  console.log(`Seeded ${convPairs.length} conversations`)

  // ---------- REVIEWS ----------
  const reviews = [
    ['بہت اچھا کام، وقت پر مکمل کیا', 'Very good work, completed on time.', 5],
    ['مناسب قیمت اور پیشہ ورانہ رویہ', 'Fair price and professional attitude.', 4.5],
    ['Great electrician, highly recommended!', '', 5],
    ['کام اچھا تھا لیکن تھوڑا دیر سے آیا', 'Good work but arrived a bit late.', 4],
    ['Excellent service, very professional.', '', 5],
    ['بہترین کام، دوبارہ ضرور بلائنگے', 'Excellent work, will definitely hire again.', 5],
    ['Good job overall, slight delay.', '', 4],
    ['Satisfied with the work. Reasonable rates.', '', 4.5],
  ]
  for (let i = 0; i < reviews.length; i++) {
    const [original, translated, rating] = reviews[i]
    const reviewerId = users[i % users.length]
    const workerId = workers[(i * 3) % workers.length]
    await db.collection('reviews').add({
      jobId: `seed-job-${i + 1}`,
      reviewerId,
      workerId,
      rating,
      originalText: original,
      originalLang: /[a-zA-Z]/.test(original) ? 'en' : 'ur',
      translatedText: translated || null,
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - i * 86400000)),
    })
    // also add a couple of location messages in the first conversation
  }
  console.log(`Seeded ${reviews.length} reviews`)

  console.log('Seed complete')
}

seed()
  .catch((err) => {
    console.error('Seed failed:', err)
    process.exit(1)
  })
