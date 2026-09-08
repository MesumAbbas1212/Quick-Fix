// Firestore seed script for QuickFix — full Pakistan dataset.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json node seed.js
//   CLEAN=1 node seed.js            # delete seeded collections first
//   REVIEWS_PER_WORKER=115 JOBS_SCALE=1   # tune volume (free-tier friendly)
//
// Seeds (with firebase-admin):
//   * categories, 18 app languages (incl. Balochi/Saraiki/Hindko)
//   * 49 workers across every province incl. Attock district, each pinned
//     to one of the five rank tiers (Apprentice 0 / Journeyman 156 /
//     Expert 312 / Master 468 / Grandmaster 624 jobs in the trailing
//     12 months — the thresholds the app's WorkerRank uses)
//   * the completed jobs that drive those ranks (completedAt inside the
//     trailing 365 days, plus a few older jobs outside the window)
//   * 100+ reviews per worker in the languages spoken across Pakistan
//     (Urdu, English, Punjabi, Pashto, Sindhi, Balochi, Saraiki, Hindko,
//     Hindi, Arabic, Persian, Bengali), each with a cached English
//     translation so the app shows it instantly without the proxy
//   * client users, open jobs for the job board, conversations
//
// Deterministic: a seeded PRNG makes repeated runs produce identical data.
'use strict'

const path = require('path')

// ------------------------------------------------------------------ config

const RANK_STEPS = 156 // policy: 156 completions per year per rank step
const RANKS = [
  { id: 'apprentice', min: 0 },
  { id: 'journeyman', min: RANK_STEPS },
  { id: 'expert', min: RANK_STEPS * 2 },
  { id: 'master', min: RANK_STEPS * 3 },
  { id: 'grandmaster', min: RANK_STEPS * 4 },
]

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
  [33.87, 72.24, 'Burhan'],
  [33.71, 72.43, 'Pindi Gheb'],
  [33.69, 72.59, 'Fateh Jang'],
  [33.64, 72.36, 'Jand'],
  [33.55, 72.57, 'Talagang Road, Attock'],
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
  [33.738, 73.0843, 'Bani Gala, Islamabad'],
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
  [27.559, 68.7824, 'Sukkur'],
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

// Worker names drawn from all over Pakistan (index 0-8 = Attock district).
const WORKER_NAMES = [
  // Attock locals
  'Ahmed Raza', 'Bilal Khan', 'Usman Ali', 'Hamza Sheikh', 'Faisal Mehmood',
  'Kamran Abbasi', 'Shahid Iqbal', 'Nasir Awan', 'Salman Pervez',
  // Punjab
  'Ali Hassan', 'Zain Malik', 'Omar Farooq', 'Tariq Mehmood', 'Shehbaz Gondal',
  'Adnan Chaudhry', 'Waqar Bhatti', 'Saqib Joya', 'Imran Gujjar',
  'Yasir Lodhi', 'Rana Sana', 'Mohsin Qayyum',
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

// App display languages (the `languages` collection). This is the
// admin-curated, data-driven source for the sign-up language picker:
// adding an entry here (or editing the collection in Firebase) makes the
// language available in the app without any code change or app release.
// Includes every major language spoken in Pakistan.
const APP_LANGUAGES = [
  ['en', 'English', 'English'],
  ['ur', 'اردو', 'Urdu'],
  ['hi', 'हिन्दी', 'Hindi'],
  ['ar', 'العربية', 'Arabic'],
  ['fa', 'فارسی', 'Persian'],
  ['es', 'Español', 'Spanish'],
  ['fr', 'Français', 'French'],
  ['de', 'Deutsch', 'German'],
  ['pt', 'Português', 'Portuguese'],
  ['tr', 'Türkçe', 'Turkish'],
  ['ru', 'Русский', 'Russian'],
  ['bn', 'বাংলা', 'Bengali'],
  ['pa', 'ਪੰਜਾਬੀ', 'Punjabi'],
  ['ps', 'پښتو', 'Pashto'],
  ['sd', 'سنڌي', 'Sindhi'],
  ['brh', 'بلوچی', 'Balochi'],
  ['skr', 'سرائیکی', 'Saraiki'],
  ['hnd', 'ہندکو', 'Hindko'],
]

// Languages a worker "speaks" (display names on the profile).
const SPEAK_SETS = [
  ['Urdu', 'English'],
  ['Urdu', 'Punjabi'],
  ['Urdu', 'Punjabi', 'English'],
  ['Urdu', 'Saraiki'],
  ['Urdu', 'Hindko'],
  ['Urdu', 'Pashto', 'English'],
  ['Urdu', 'Sindhi', 'English'],
  ['Urdu', 'Balochi'],
  ['Urdu', 'English', 'Hindi'],
]

// ------------------------------------------------- review template pools
// Each entry: [nativeText, englishTranslation, sentiment(pos|neu|neg)].
// Placeholders filled at generation time: {prof} profession, {city} city.

const REVIEW_TEMPLATES = {
  ur: [
    ['بہت اچھا کام، وقت پر مکمل کیا', 'Very good work, completed on time.', 'pos'],
    ['مناسب قیمت اور پیشہ ورانہ رویہ', 'Fair price and professional attitude.', 'pos'],
    ['بہترین سروس، دوبارہ ضرور لیا جائے گا', 'Excellent service, will definitely hire again.', 'pos'],
    ['کام اچھا تھا لیکن تھوڑا دیر سے آیا', 'Good work but arrived a bit late.', 'neu'],
    ['ماہر ہاتھ، صاف ستھرہ کام', 'Expert hands, clean and neat work.', 'pos'],
    ['ہر چیز ٹھیک کر دی، بہت مہربان لوگ', 'Fixed everything, very courteous people.', 'pos'],
    ['قیمت تھوڑی زیادہ لیکن کام معیاری تھا', 'Price a bit high but the work was quality.', 'neu'],
    ['دو بار کال کی تو دونوں بار فوری آ گئے', 'Called twice and both times came immediately.', 'pos'],
    ['پرانے موٹر کو نیا کر دیا', 'Made the old motor like new.', 'pos'],
    ['کام میں بہت آہستہ پن تھا، آخری لمحے تک لگا', 'Work was very slow, kept going till the last minute.', 'neg'],
    ['اپنیاں ٹولز لے کر آئے، وقت بچ گیا', 'Came with own tools, saved time.', 'pos'],
    ['ایک چیز ٹھیک ہوئی، دوسری خراب کر دی', 'One thing got fixed, another got broken.', 'neg'],
    ['گھر میں بچے تھے، پھر بھی احتیاط سے کام کیا', 'There were kids at home, still worked with care.', 'pos'],
    ['فون پر قیمت بتائی، بعد میں کثیر لیا گیا', 'Quoted over the phone, much more was taken later.', 'neg'],
    ['آپ کی خدمات کے لیے شکرگزار ہیں', 'Grateful for your services.', 'pos'],
    ['کام {city} کے بہترین لوگوں کی طرح ہوا', 'The work was done like the best people in {city}.', 'pos'],
  ],
  en: [
    ['Very good work, completed on time.', 'Very good work, completed on time.', 'pos'],
    ['Fair price and professional attitude.', 'Fair price and professional attitude.', 'pos'],
    ['Excellent service, will definitely hire again.', 'Excellent service, will definitely hire again.', 'pos'],
    ['Good work but arrived a bit late.', 'Good work but arrived a bit late.', 'neu'],
    ['Expert hands, clean and neat work.', 'Expert hands, clean and neat work.', 'pos'],
    ['Fixed everything and explained how to care for it.', 'Fixed everything and explained how to care for it.', 'pos'],
    ['Price a bit high but the work was quality.', 'Price a bit high but the work was quality.', 'neu'],
    ['Called twice and both times came immediately.', 'Called twice and both times came immediately.', 'pos'],
    ['Made the old motor like new.', 'Made the old motor like new.', 'pos'],
    ['Work was very slow, kept going till the last minute.', 'Work was very slow, kept going till the last minute.', 'neg'],
    ['Came with own tools, saved us a lot of time.', 'Came with own tools, saved us a lot of time.', 'pos'],
    ['One thing got fixed, another got broken.', 'One thing got fixed, another got broken.', 'neg'],
    ['Very careful with our furniture and floors.', 'Very careful with our furniture and floors.', 'pos'],
    ['Quoted over the phone, charged much more later.', 'Quoted over the phone, charged much more later.', 'neg'],
    ['Highly recommended for {city}.', 'Highly recommended for {city}.', 'pos'],
    ['Done the {prof} job better than expected.', 'Done the {prof} job better than expected.', 'pos'],
  ],
  pa: [
    ['ਬਹੁਤ ਚੰਗਾ ਕੰਮ, ਸਮੇਂ ਸਿਰ ਪਹੁੰਚ ਗਏ', 'Very good work, arrived on time.', 'pos'],
    ['ਕੰਮ ਮਜ਼ਬੂਤ ਹੈ, ਕੀਮਤ ਵੀ ਠੀਕ ਸੀ', 'The work is solid, the price was right too.', 'pos'],
    ['ਔਖਾ ਕੰਮ ਸੀ ਪਰ ਬਹੁਤ ਚੰਗੀ ਤਰੀਕੇ ਨਾਲ ਸਾਂਭਿਆ', 'It was a difficult job but handled it very well.', 'pos'],
    ['ਥੋੜਾ ਦੇਰ ਹੋਈ ਪਰ ਕੰਮ ਚੰਗਾ ਨਿਕਲਿਆ', 'A bit late but the work turned out good.', 'neu'],
    ['ਪੁਰਾਣਾ ਪੰਖਾ ਹੁਣ ਨਵਾਂ ਲੱਗਦਾ ਹੈ', 'The old fan looks new now.', 'pos'],
    ['ਬਹੁਤ ਮਿੱਠੇ ਅੰਦਾਜ਼ੇ ਦੇ ਹਨ', 'They are very sweet in manner.', 'pos'],
    ['ਦੋ ਦਿਨਾਂ ਬਾਅਦ ਫਿਰ ਆਣਾ ਪਿਆ', 'Had to come back after two days.', 'neg'],
    ['ਕੀਮਤ ਬਹੁਤ ਜ਼ਿਆਦਾ ਮੰਗੀ', 'They asked for a very high price.', 'neg'],
    ['ਘਰ ਦੇ ਸਾਰੇ ਕੰਮ ਹੁਣ ਉਹਨਾਂ ਨੂੰ ਦਿੰਦੇ ਹਾਂ', 'We now give them all the work at home.', 'pos'],
    ['ਕੰਮ ਹੋਇਆ ਪਰ ਥੋੜਾ ਉਲਝਣ ਰਹੀ', 'The work got done but a bit of mess remained.', 'neu'],
  ],
  ps: [
    ['ښه کار وکړ, وخت پر ورسېد', 'Did good work, arrived on time.', 'pos'],
    ['کار زړه راښکونکى و', 'The work was very satisfying.', 'pos'],
    ['بیا به یې بلل', 'We will call them again.', 'pos'],
    ['کار درانه و, مهربان کس دی', 'Honest work, a kind person.', 'pos'],
    ['لږ ورو ورسېد خو کار یې ښه و', 'Arrived a little late but the work was good.', 'neu'],
    ['کار نه شو کړی, بیرته یې راکاږه', 'The work did not work out, had to redo it.', 'neg'],
    ['بشپړ وخت یې لګېد', 'It took the full time.', 'neu'],
    ['په {city} کې غوره کارګر دی', 'The best worker in {city}.', 'pos'],
  ],
  sd: [
    ['سٻا ڪم ڪيو، وقت تي آيو', 'Did the work well, came on time.', 'pos'],
    ['ڪو ڏک نه ٿيو، ٻيهر ڇڪنداسين', 'No disappointment, will call again.', 'pos'],
    ['کمن ۽ اڻ وارا آهن', 'They are humble and knowledgeable.', 'pos'],
    ['ٿورڙو مهانگو هو پر ڪم ڄاڻوارن وارو', 'A bit expensive but knowledgeable work.', 'neu'],
    ['ٻيهر ٻيهر آڻيو', 'Had to call back again and again.', 'neg'],
    ['ڪم ٿيو پر ڏينهن ٿيا وڌيڪ', 'The work got done but took too many days.', 'neu'],
    ['ڪجهه ٽڪرا ٽٽو ڇڏيو', 'Left some things broken.', 'neg'],
    ['سمجه ۾ آيا، ڀلي ڪري ڪم ڪيو', 'Understood well and did the work carefully.', 'pos'],
  ],
  brh: [
    ['ښو ډاځ ڪړ، وخت پر رسید', 'Did good work, arrived on time.', 'pos'],
    ['کار زوردار ای', 'The work is solid.', 'pos'],
    ['چاک و پاک کارگر', 'A clean-work doer.', 'pos'],
    ['وروستو رسید، کار ښو ای', 'Arrived late, the work was good.', 'neu'],
    ['کار بیا ورکر', 'The work had to be redone.', 'neg'],
    ['ګران بولی، کار ښو ای', 'Asked a high price, the work was good.', 'neu'],
  ],
  skr: [
    ['اچّے کم کیتا، وکته تے آ کھڑا', 'Did good work, came on time.', 'pos'],
    ['پکّے کمے دارن، وری ویلن دا', 'Skilled workers, will hire again.', 'pos'],
    ['کم ٹھیک آ پر وکٹ چھوڑی', 'The work is right but the price was high.', 'neu'],
    ['دو ڀاری وچ ویاءن، کم ھویا', 'Had to call twice, the work failed.', 'neg'],
    ['ڄاڳ دے لوک آ پُکھتے', 'A knowledgeable person of the area.', 'pos'],
    ['کمی ہئی پر کم ورتا ویندے', 'There was a lack but the work works.', 'neu'],
  ],
  hnd: [
    ['بھڑا کم کیتے، وخت تے آ ویندے', 'Did very good work, comes on time.', 'pos'],
    ['کم ٹھیک آ، ورتا ویندے', 'The work is right, it works.', 'pos'],
    ['ڄانے والے آ، کم پکّا آ', 'A knowledgeable one, the work is solid.', 'pos'],
    ['دیر تے آئے پر کم چڙیا', 'Came late but the work got done.', 'neu'],
    ['وچ ویلے دے، کم گھری', 'Had to call in the middle, the work failed.', 'neg'],
    ['وکت پورے کم کیتے', 'Did the complete work within the time.', 'pos'],
  ],
  hi: [
    ['बहुत अच्छा काम, समय पर पूरा किया', 'Very good work, completed on time.', 'pos'],
    ['किमत सही और काम शानदार', 'Fair price and great work.', 'pos'],
    ['पेशेवर अंदाज़, हर किसी को सुझाते हैं', 'Professional attitude, recommend to everyone.', 'pos'],
    ['थोड़ी देर हुई पर काम अच्छा रहा', 'A little late but the work stayed good.', 'neu'],
    ['पुराना पंखा अब नया लगेगा', 'The old fan will look new now.', 'pos'],
    ['फिर से खेरी खाना पड़ी, काम ठीक नहीं था', 'Had to rehire, the work was not right.', 'neg'],
    ['दाम ज़्यादा लिए', 'Charged too much.', 'neg'],
    ['घर का सारा काम अब इनके पास जाता है', 'All the work at home now goes to them.', 'pos'],
  ],
  ar: [
    ['عمل ممتاز، وصل في الوقت المحدد', 'Excellent work, arrived on time.', 'pos'],
    ['سعر مناسب وأسلوب محترم', 'Fair price and respectful manner.', 'pos'],
    ['تأخر قليلاً لكن النتيجة كانت جيدة', 'Late a little but the result was good.', 'neu'],
    ['أُعيد العمل مرتين', 'The work had to be redone twice.', 'neg'],
    ['تقنية عالية وأسعار مقبولة', 'High skill and acceptable prices.', 'pos'],
    ['لم يُنجز المهمة بشكل كامل', 'Did not complete the task fully.', 'neg'],
  ],
  fa: [
    ['کار عالی بود، به وقت رسید', 'The work was great, arrived on time.', 'pos'],
    ['قیمت منصفانه و رفتار حرفه‌ای', 'Fair price and professional behavior.', 'pos'],
    ['دیر رسید ولی کارش خوب بود', 'Arrived late but the work was good.', 'neu'],
    ['کار دوباره از سر گرفته شد', 'The work had to be started over.', 'neg'],
    ['دستِ ماهر، کار تمیز', 'Skilled hands, clean work.', 'pos'],
    ['هزینه از حد انتظار بیشتر بود', 'The cost was more than expected.', 'neu'],
  ],
  bn: [
    ['খুব ভালো কাজ, সময় মতো শেষ করে', 'Very good work, finished on time.', 'pos'],
    ['দাম সঠিক এবং কাজ দারুণ', 'Right price and great work.', 'pos'],
    ['একটু দেরি হয়েছে কিন্তু কাজ ভালো', 'A little late but the work is good.', 'neu'],
    ['কাজটা আবার করতে হয়েছে', 'Had to redone the work.', 'neg'],
    ['হাতে দক্ষতা আছে, কাজ পরিষ্কার', 'Skilled in hands, clean work.', 'pos'],
    ['খরচ বেশি হয়ে গেছে', 'The cost has become high.', 'neu'],
  ],
}

// Review language mix: the languages actually spoken across Pakistan.
const REVIEW_LANG_WEIGHTS = [
  ['ur', 0.30], ['en', 0.22], ['pa', 0.14], ['ps', 0.08], ['sd', 0.08],
  ['brh', 0.05], ['skr', 0.04], ['hnd', 0.03], ['hi', 0.025], ['ar', 0.02],
  ['fa', 0.02], ['bn', 0.015],
]

const SENTIMENT_WEIGHTS = [['pos', 0.55], ['neu', 0.30], ['neg', 0.15]]
const RATING_RANGES = { pos: [4.5, 5], neu: [3.5, 4], neg: [2, 3.5] }

// Per-worker rank plan: tier index into RANKS. First nine are Attock
// district and cover all five tiers.
const ATTOCK_PLAN = [1, 4, 2, 0, 3, 1, 2, 0, 3]
const REST_PLAN_CYCLE = [0, 2, 1, 3, 1, 4, 2, 0, 1, 3, 2, 4, 0, 1, 2, 3, 1, 0]

// [min, max] in-year completed jobs for each tier.
const TIER_RANGES = [
  [0, 155], [156, 311], [312, 467], [468, 623], [624, 700],
]

// Optional volume tuning (free-tier friendly):
//   JOBS_SCALE=0.3        -> fewer completed jobs (rank is preserved)
//   REVIEWS_PER_WORKER=40 -> fixed review count per worker
const JOBS_SCALE = Math.min(1, Math.max(0.05, parseFloat(process.env.JOBS_SCALE || '1')))
const REVIEWS_PER_WORKER = Math.max(0, parseInt(process.env.REVIEWS_PER_WORKER || '0', 10))

// Job counts that land each tier inside its range; JOBS_SCALE moves the
// position within the range without crossing tier boundaries.
function jobsForTier(tierIdx, rng) {
  const [lo, hi] = TIER_RANGES[tierIdx]
  if (tierIdx === 0) return Math.floor(rng() * 45) // 0-44, stays Apprentice
  const f = Math.min(0.95, Math.max(0.1, 0.15 + 0.75 * JOBS_SCALE))
  return Math.min(hi, lo + Math.floor(f * (hi - lo) + rng() * 10))
}

// Deterministic PRNG (mulberry32) so runs are reproducible.
function makeRng(seed) {
  let a = seed >>> 0
  return function rng() {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function pickWeighted(rng, pairs) {
  const total = pairs.reduce((s, [, w]) => s + w, 0)
  const r = rng() * total
  let acc = 0
  for (const [val, w] of pairs) {
    acc += w
    if (r < acc) return val
  }
  return pairs[pairs.length - 1][0]
}
// ---------------------------------------------------------------- generator

const JOB_TITLES = {
  plumbing: ['Kitchen sink leak', 'Bathroom faucet drip', 'Water heater repair', 'Pipe replacement', 'Drain blockage', 'Shower valve fix'],
  electrical: ['Ceiling fan installation', 'AC wiring', 'Switch board replacement', 'Inverter installation', 'Socket replacement', 'Light fitting repair'],
  cleaning: ['Deep home cleaning', 'Post-remodel cleanup', 'Sofa and carpet cleaning', 'Window cleaning', 'Kitchen deep clean'],
  carpentry: ['Wardrobe repair', 'Door frame fixing', 'Tabletop sanding', 'Bench assembly', 'Window shutter repair'],
  painting: ['Bedroom repaint', 'Living room paint', 'Exterior touch-up', 'Ceiling water-mark paint', 'Gentleman coat'],
  gardening: ['Lawn trimming', 'Tree branch cutting', 'Garden bed setup', 'Hedge shaping'],
  moving: ['Home shifting help', 'Office shifting', 'Furniture packing', 'Loading and unloading'],
  applianceRepair: ['AC not cooling', 'Refrigerator repair', 'Washing machine service', 'Microwave repair', 'Geysere not heating'],
}

const JOB_DESCRIPTIONS = [
  'Urgent home service needed. Please contact for details.',
  'Looking for an experienced professional for this task.',
  'Need this done this week. Flexible on timing.',
  'Small job but need quality work. Tools provided if needed.',
  'Please share your quote and availability.',
  'Regular household job, long-term client.',
]

function buildDataset() {
  const rng = makeRng(42)
  const now = Date.now()
  const DAY = 86400000

  const clientUsers = USER_NAMES.map((name, i) => ({
    uid: `user-${i + 1}`,
    fullName: name,
    email: `user${i + 1}@quickfix.test`,
    phone: `0321${2000000 + i * 22222}`,
  }))

  const workers = []
  const jobs = []
  const reviews = []

  WORKER_NAMES.forEach((name, i) => {
    const tierIdx = i < 9 ? ATTOCK_PLAN[i] : REST_PLAN_CYCLE[(i - 9) % REST_PLAN_CYCLE.length]
    const [lat, lng, city] = CITIES[i % CITIES.length]
    const uid = `worker-${i + 1}`
    const profession = CATEGORIES[i % CATEGORIES.length][0]
    const secondProfession = CATEGORIES[(i + 3) % CATEGORIES.length][0]
    const professionLabel = profession.replace(/([A-Z])/g, ' $1').toLowerCase()
    const inYear = jobsForTier(tierIdx, rng)
    const oldCount = 1 + Math.floor(rng() * 3) // 1-3 jobs outside the 365d window

    // ---- completed jobs (drive the rank via the trailing-year window) ----
    const jobIds = []
    const step = inYear > 0 ? 360 / inYear : 0
    for (let j = 0; j < inYear; j++) {
      const daysAgo = 1 + Math.floor(j * step) + Math.floor(rng() * 3)
      const completedAt = now - daysAgo * DAY
      const id = `job-${i + 1}-${j + 1}`
      jobIds.push(id)
      const [clat, clng, ccity] = CITIES[(i + j) % CITIES.length]
      jobs.push({
        id,
        userId: clientUsers[Math.floor(rng() * clientUsers.length)].uid,
        workerId: uid,
        title: JOB_TITLES[profession][j % JOB_TITLES[profession].length],
        description: JOB_DESCRIPTIONS[j % JOB_DESCRIPTIONS.length],
        category: profession,
        address: j % 5 === 0 ? ccity : city,
        location: { lat: clat + (rng() - 0.5) * 0.02, lng: clng + (rng() - 0.5) * 0.02 },
        budgetMin: 800 + Math.floor(rng() * 1500),
        budgetMax: 2000 + Math.floor(rng() * 3500),
        status: 'completed',
        rating: rng() < 0.75 ? 5 : 4,
        createdAt: completedAt - 86400000,
        assignedAt: completedAt - 43200000,
        updatedAt: completedAt,
        completedAt,
      })
    }
    for (let k = 0; k < oldCount; k++) {
      const daysAgo = 400 + k * 60 + Math.floor(rng() * 30)
      const completedAt = now - daysAgo * DAY
      jobs.push({
        id: `job-${i + 1}-old-${k + 1}`,
        userId: clientUsers[Math.floor(rng() * clientUsers.length)].uid,
        workerId: uid,
        title: JOB_TITLES[profession][k % JOB_TITLES[profession].length],
        description: JOB_DESCRIPTIONS[k % JOB_DESCRIPTIONS.length],
        category: profession,
        address: city,
        location: { lat: lat + (rng() - 0.5) * 0.02, lng: lng + (rng() - 0.5) * 0.02 },
        budgetMin: 900,
        budgetMax: 2400,
        status: 'completed',
        rating: 4,
        createdAt: completedAt - 86400000,
        assignedAt: completedAt - 43200000,
        updatedAt: completedAt,
        completedAt,
      })
    }

    // ---- reviews: 100+ per worker, languages of Pakistan ----
    // Default: 100-140 reviews per worker. Override with REVIEWS_PER_WORKER.
    const reviewCount = REVIEWS_PER_WORKER > 0
      ? REVIEWS_PER_WORKER
      : 100 + Math.floor(rng() * 41) // 100-140
    let ratingSum = 0
    for (let r = 0; r < reviewCount; r++) {
      const lang = pickWeighted(rng, REVIEW_LANG_WEIGHTS)
      const sentiment = pickWeighted(rng, SENTIMENT_WEIGHTS)
      const pool = REVIEW_TEMPLATES[lang].filter((t) => t[2] === sentiment)
      const tpl = pool[Math.floor(rng() * pool.length)]
      const fill = (t) => t.replace('{city}', city).replace('{prof}', professionLabel)
      const [minR, maxR] = RATING_RANGES[sentiment]
      const rating = Math.round((minR + rng() * (maxR - minR)) * 2) / 2
      ratingSum += rating
      const daysAgo = Math.floor(rng() * 400)
      reviews.push({
        id: `rev-${i + 1}-${r + 1}`,
        jobId: jobIds.length ? jobIds[Math.floor(rng() * jobIds.length)] : `job-${i + 1}-old-1`,
        reviewerId: clientUsers[Math.floor(rng() * clientUsers.length)].uid,
        workerId: uid,
        rating,
        originalText: fill(tpl[0]),
        originalLang: lang,
        translatedText: lang === 'en' ? null : fill(tpl[1]),
        translations: lang === 'en' ? {} : { en: fill(tpl[1]) },
        createdAt: now - daysAgo * DAY - Math.floor(rng() * 86400000),
      })
    }
    const avgRating = Math.round((ratingSum / reviewCount) * 10) / 10

    workers.push({
      uid,
      fullName: name,
      email: `worker${i + 1}@quickfix.test`,
      phone: `0300${1000000 + i * 11111}`,
      about: `${professionLabel[0].toUpperCase() + professionLabel.slice(1)} professional serving ${city} and nearby areas. ${3 + (i % 12)} years of experience. Quality work at fair prices.`,
      professions: [profession, secondProfession],
      languages: SPEAK_SETS[i % SPEAK_SETS.length],
      location: { lat: lat + (rng() - 0.5) * 0.02, lng: lng + (rng() - 0.5) * 0.02 },
      city,
      minBudget: 800 + Math.floor(rng() * 700),
      maxBudget: 3000 + Math.floor(rng() * 3000),
      rating: avgRating,
      completedJobs: inYear + oldCount,
      reviews: reviewCount,
      isAvailable: rng() > 0.2,
      approved: true,
      blocked: false,
      tierIdx,
      inYear,
      createdAt: now - 700 * DAY,
      updatedAt: now,
    })
  })

  // ---- open jobs for the client job board ----
  const openJobs = []
  for (let i = 0; i < 40; i++) {
    const [lat, lng, city] = CITIES[i % CITIES.length]
    const cat = CATEGORIES[i % CATEGORIES.length][0]
    openJobs.push({
      id: `open-${i + 1}`,
      userId: clientUsers[i % clientUsers.length].uid,
      workerId: null,
      title: JOB_TITLES[cat][i % JOB_TITLES[cat].length],
      description: JOB_DESCRIPTIONS[i % JOB_DESCRIPTIONS.length],
      category: cat,
      address: city,
      location: { lat: lat + (rng() - 0.5) * 0.01, lng: lng + (rng() - 0.5) * 0.01 },
      budgetMin: 1000 + Math.floor(rng() * 1000),
      budgetMax: 2500 + Math.floor(rng() * 2500),
      status: 'open',
      rating: null,
      createdAt: now - i * 3600000,
      updatedAt: now,
      completedAt: null,
    })
  }

  const conversations = [
    ['user-1', 'worker-1'], ['user-2', 'worker-3'], ['user-3', 'worker-5'], ['user-4', 'worker-2'],
  ].map(([u, w]) => ({
    id: [u, w].sort().join('_'),
    participants: [u, w],
    lastMessage: 'Great, I will be there at 10 AM',
    lastSenderId: w,
    messages: [
      { senderId: u, text: 'Hi, I need help with AC repair', ago: 4 },
      { senderId: w, text: 'Yes sure, when do you need it?', ago: 3 },
      { senderId: u, text: 'Tomorrow morning works', ago: 2 },
      { senderId: w, text: 'Great, I will be there at 10 AM', ago: 1 },
    ],
  }))

  return {
    categories: CATEGORIES,
    languages: APP_LANGUAGES,
    clientUsers,
    workers,
    jobs,
    reviews,
    openJobs,
    conversations,
  }
}

// -------------------------------------------------------------------- seed

async function seed() {
  let admin
  try {
    admin = require('firebase-admin')
  } catch {
    console.error('firebase-admin is not installed. Run: npm install firebase-admin')
    process.exit(1)
  }
  admin.initializeApp({ credential: admin.credential.applicationDefault() })
  const db = admin.firestore()
  const now = Date.now()
  const ts = admin.firestore.Timestamp.now()

  const data = buildDataset()
  const geo = (l) => new admin.firestore.GeoPoint(l.lat, l.lng)
  const t = (ms) => (ms == null ? null : admin.firestore.Timestamp.fromDate(new Date(ms)))

  // ---- optional clean ----
  if (process.env.CLEAN === '1') {
    for (const col of ['reviews', 'jobs', 'workers', 'users', 'categories', 'languages', 'conversations']) {
      let deleted = 0
      for (;;) {
        const snap = await db.collection(col).limit(450).get()
        if (snap.empty) break
        const batch = db.batch()
        snap.docs.forEach((d) => batch.delete(d.ref))
        await batch.commit()
        deleted += snap.size
        if (snap.size < 450) break
      }
      if (deleted) console.log(`CLEAN: removed ${deleted} docs from ${col}`)
    }
  }

  // ---- categories + languages ----
  let batch = db.batch()
  for (const [id, name, description] of data.categories) {
    batch.set(db.collection('categories').doc(id), {
      name, description, iconPath: `assets/categories/${id}.png`, createdAt: ts,
    })
  }
  for (const [code, nativeName, englishName] of data.languages) {
    batch.set(db.collection('languages').doc(code), {
      code, nativeName, englishName, createdAt: ts,
    })
  }
  await batch.commit()
  console.log(`Seeded ${data.categories.length} categories, ${data.languages.length} app languages`)

  // ---- users (workers + clients) ----
  batch = db.batch()
  for (const w of data.workers) {
    batch.set(db.collection('users').doc(w.uid), {
      fullName: w.fullName,
      email: w.email,
      phone: w.phone,
      role: 'worker',
      rating: w.rating,
      completedJobs: w.completedJobs,
      createdAt: ts,
      updatedAt: ts,
    })
  }
  for (const u of data.clientUsers) {
    batch.set(db.collection('users').doc(u.uid), {
      fullName: u.fullName, email: u.email, phone: u.phone, role: 'user',
      createdAt: ts, updatedAt: ts,
    })
  }
  await batch.commit()
  console.log(`Seeded ${data.workers.length + data.clientUsers.length} users`)

  // ---- workers ----
  batch = db.batch()
  for (const w of data.workers) {
    const { tierIdx, inYear, ...doc } = w
    doc.location = geo(w.location)
    doc.createdAt = t(w.createdAt)
    doc.updatedAt = t(w.updatedAt)
    batch.set(db.collection('workers').doc(w.uid), doc)
  }
  await batch.commit()
  console.log(`Seeded ${data.workers.length} workers (Attock district covered in every rank tier)`)

  // ---- completed jobs (rank drivers) + open jobs ----
  let written = 0
  for (let i = 0; i < data.jobs.length; i += 450) {
    batch = db.batch()
    data.jobs.slice(i, i + 450).forEach((j) => {
      const { id, location, ...doc } = j
      doc.location = geo(location)
      doc.createdAt = t(j.createdAt)
      doc.assignedAt = t(j.assignedAt)
      doc.updatedAt = t(j.updatedAt)
      doc.completedAt = t(j.completedAt)
      batch.set(db.collection('jobs').doc(id), doc)
    })
    await batch.commit()
    written += Math.min(450, data.jobs.length - i)
    process.stdout.write(`\rCompleted jobs: ${written}/${data.jobs.length}`)
  }
  console.log()
  batch = db.batch()
  for (const j of data.openJobs) {
    const { id, location, ...doc } = j
    doc.location = geo(location)
    doc.createdAt = t(j.createdAt)
    doc.updatedAt = t(j.updatedAt)
    doc.completedAt = null
    batch.set(db.collection('jobs').doc(id), doc)
  }
  await batch.commit()
  console.log(`Seeded ${data.jobs.length} completed + ${data.openJobs.length} open jobs`)

  // ---- reviews ----
  written = 0
  for (let i = 0; i < data.reviews.length; i += 450) {
    batch = db.batch()
    data.reviews.slice(i, i + 450).forEach((r) => {
      const { id, createdAt, ...doc } = r
      doc.createdAt = t(createdAt)
      batch.set(db.collection('reviews').doc(id), doc)
    })
    await batch.commit()
    written += Math.min(450, data.reviews.length - i)
    process.stdout.write(`\rReviews: ${written}/${data.reviews.length}`)
  }
  console.log()
  console.log(`Seeded ${data.reviews.length} reviews`)

  // ---- conversations ----
  for (const c of data.conversations) {
    for (const m of c.messages) {
      const receiver = c.participants.find((p) => p !== m.senderId)
      await db.collection('conversations').doc(c.id).collection('messages').add({
        senderId: m.senderId,
        receiverId: receiver,
        text: m.text,
        createdAt: t(now - m.ago * 3600000),
        read: true,
        isRead: true,
      })
    }
    await db.collection('conversations').doc(c.id).set({
      participants: c.participants,
      lastMessage: c.lastMessage,
      lastMessageAt: ts,
      lastSenderId: c.lastSenderId,
      unreadCount: 0,
    })
  }
  console.log(`Seeded ${data.conversations.length} conversations`)

  // ---- summary ----
  const tierName = (i) => RANKS[i].id
  console.log('\n' + '='.repeat(96))
  console.log('Worker                          City (truncated)              Tier         InYear  Reviews  Rating')
  console.log('='.repeat(96))
  for (const w of data.workers) {
    const line =
      `${w.fullName.padEnd(27)} ${(w.city).padEnd(27).slice(0, 27)} ${tierName(w.tierIdx).padEnd(11)} ${String(w.inYear).padEnd(7)} ${String(w.reviews).padEnd(8)} ${w.rating}`
    console.log(line)
  }
  const tierCounts = RANKS.map((_, i) => data.workers.filter((w) => w.tierIdx === i).length)
  console.log('='.repeat(96))
  console.log(
    `Tiers -> Apprentice: ${tierCounts[0]} | Journeyman: ${tierCounts[1]} | Expert: ${tierCounts[2]} | Master: ${tierCounts[3]} | Grandmaster: ${tierCounts[4]}`,
  )
  console.log(
    `Totals: ${data.workers.length} workers | ${data.jobs.length + data.openJobs.length} jobs | ${data.reviews.length} reviews | ${data.clientUsers.length} clients`,
  )
  console.log('Seed complete')
}

if (require.main === module) {
  seed().catch((err) => {
    console.error('Seed failed:', err)
    process.exit(1)
  })
} else {
  module.exports = { buildDataset, RANKS, RANK_STEPS, REVIEW_TEMPLATES, REVIEW_LANG_WEIGHTS, WORKER_NAMES, CITIES }
}
