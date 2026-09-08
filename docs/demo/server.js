// QuickFix interactive demo — new features walkthrough.
//
// ML pipeline (runs locally, zero dependencies):
//   * Translation — statistical machine translation, trained at startup from
//     a bundled 4-way parallel corpus (data/parallel_corpus.json, en/ur/fr/hi):
//       - word-level Bayes model P(w_tgt | w_src) (max likelihood + Laplace
//         smoothing, English pivot) as the fallback
//       - phrase table: 2- and 3-word longest-match phrases mined from the
//         aligned sentences, so common review phrases translate as units
//       - translation memory: fuzzy sentence matching against the corpus
//     The production app instead calls the key-protected translation proxy
//     (Google Cloud Translation = neural MT).
//   * Review summarization — TF-IDF extractive summarization: sentence
//     scoring with term frequency × inverse document frequency, lexicon
//     guided selection, 1 paragraph for <=4 reviews, 2 paragraphs for more.
//
// Run:  node docs/demo/server.js   ->  http://localhost:8090
const http = require('http')
const fs = require('fs')
const path = require('path')

const PORT = process.env.PORT || 8090
const DATA = path.join(__dirname, 'data')
const COLLECTION_FILE = path.join(DATA, 'languages.json')
const PROXY_FILE = path.join(DATA, 'proxy-languages.json')
const CORPUS_FILE = path.join(DATA, 'parallel_corpus.json')

// ================================================================ ML: SMT

const LANGS = ['en', 'ur', 'fr', 'hi']
const RTL = new Set(['ur', 'ar', 'fa', 'ps', 'sd'])

const STOPWORDS = new Set([
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'of', 'and', 'or', 'to',
  'in', 'on', 'at', 'it', 'he', 'she', 'they', 'i', 'you', 'we', 'my',
  'your', 'for', 'with', 'this', 'that', 'now', 'very', 'but', 'not',
])
const STOPWORDS_NONLATIN = new Set([
  'ہے', 'ہیں', 'تھا', 'تھی', 'ہو', 'اور', 'کی', 'کا', 'کے', 'کو', 'سے',
  'پر', 'یہ', 'وہ', 'میں', 'اس', 'اچھا', 'ہوئے', 'ہے۔', 'کر', 'کیا',
  'le', 'la', 'les', 'est', 'et', 'de', 'des', 'un', 'une', 'il', 'elle',
  'très', 'dans', 'pour', 'par', 'a', 'au', 'aux', 'du', 'que', 'que.',
  'है', 'हैं', 'था', 'और', 'का', 'की', 'के', 'को', 'से', 'पर', 'यह', 'वह',
  'में', 'इस', 'बहुत', 'रहता', 'रहती', 'कर', 'की।',
])

function tokenize(text, lang) {
  const rtl = RTL.has(lang)
  let t = String(text).toLowerCase()
  const punct = rtl
    ? /[،。؟?!،؛;\.,:]/g
    : /[.,!?;:'’-]+/g
  t = t.replace(punct, ' ')
  return t.split(/\s+/).filter(Boolean)
}

function normalize(text) {
  return tokenize(text, 'xx').join(' ')
}

// --- word translation tables, English pivot -------------------------------
// pairCount["ur|en"]["word"] = Map(englishWord -> count)
const pairCount = {}
const margCount = {}
let alignmentCount = 0

function bumpPair(a, b, wa, wb) {
  const key = `${a}|${b}`
  if (!pairCount[key]) pairCount[key] = {}
  if (!pairCount[key][wa]) pairCount[key][wa] = new Map()
  pairCount[key][wa].set(wb, (pairCount[key][wa].get(wb) || 0) + 1)
  if (!margCount[key]) margCount[key] = {}
  margCount[key][wa] = (margCount[key][wa] || 0) + 1
  alignmentCount++
}

function trainSMT(corpus) {
  for (const s of corpus) {
    for (const code of ['ur', 'fr', 'hi']) {
      const wEn = tokenize(s.en, 'en')
      const wX = tokenize(s[code], code)
      if (Math.abs(wEn.length - wX.length) > 2) continue
      const m = Math.min(wEn.length, wX.length)
      for (let i = 0; i < m; i++) {
        bumpPair(code, 'en', wX[i], wEn[i])
        bumpPair('en', code, wEn[i], wX[i])
      }
    }
  }
}

function tableSize() {
  let pairs = 0
  for (const key of Object.keys(pairCount)) {
    for (const w of Object.keys(pairCount[key])) pairs += pairCount[key][w].size
  }
  return pairs
}

// --- translation memory ----------------------------------------------------
const TM = [] // { norm: {code: string}, text: {code: string} }

function buildTM(corpus) {
  for (const s of corpus) {
    TM.push({
      norm: { en: normalize(s.en), ur: normalize(s.ur), fr: normalize(s.fr), hi: normalize(s.hi) },
      text: { en: s.en, ur: s.ur, fr: s.fr, hi: s.hi },
    })
  }
}

function jaccard(a, b) {
  const A = new Set(a.split(' '))
  const B = new Set(b.split(' '))
  if (!A.size || !B.size) return 0
  let inter = 0
  for (const w of A) if (B.has(w)) inter++
  return inter / (A.size + B.size - inter)
}

// --- phrase table (longest-match, from 1:1 aligned sentences) ---------------
const PHRASES = {} // "from|to|n" -> Map(srcPhrase -> { phrase, count })

function phraseCount() {
  let c = 0
  for (const key of Object.keys(PHRASES)) c += PHRASES[key].size
  return c
}

function buildPhrases(corpus) {
  for (const e of corpus) {
    for (const s of LANGS) {
      for (const t of LANGS) {
        if (s === t) continue
        const A = tokenize(e[s], s)
        const B = tokenize(e[t], t)
        if (A.length !== B.length) continue
        for (const n of [3, 2]) {
          for (let i = 0; i + n <= A.length; i++) {
            const key = `${s}|${t}|${n}`
            if (!PHRASES[key]) PHRASES[key] = new Map()
            const p = A.slice(i, i + n).join(' ')
            const q = B.slice(i, i + n).join(' ')
            const rec = PHRASES[key].get(p)
            if (rec) rec.count++
            else PHRASES[key].set(p, { phrase: q, count: 1 })
          }
        }
      }
    }
  }
}

function argmax(target, src, from, to) {
  const key = `${from}|${to}`
  const row = pairCount[key] && pairCount[key][src]
  if (!row) return null
  let best = null
  let bestP = 0
  const V = 50
  for (const [w, c] of row) {
    const p = (c + 1) / ((margCount[key][src] || 1) + V)
    if (p > bestP) {
      bestP = p
      best = w
    }
  }
  return best
}

function translateWordPivot(word, from, to) {
  if (from === to) return { word, evidence: true }
  if (from === 'en') {
    const t = argmax(null, word, 'en', to)
    return { word: t || word, evidence: !!t }
  }
  if (to === 'en') {
    const t = argmax(null, word, from, 'en')
    return { word: t || word, evidence: !!t }
  }
  // pivot through English
  const mid = argmax(null, word, from, 'en')
  const midWord = mid || word
  const fin = argmax(null, midWord, 'en', to)
  return { word: fin || midWord, evidence: !!mid && !!fin }
}

function translate(text, src, target) {
  if (!text) return { translated: '', confidence: 0, method: 'none' }
  if (src === target) return { translated: text, confidence: 1, method: 'identity' }

  // 1) translation memory (fuzzy match)
  const norm = normalize(text)
  let bestSim = 0
  let bestEntry = null
  for (const e of TM) {
    const sim = jaccard(norm, e.norm[src] || e.norm.en)
    if (sim > bestSim) {
      bestSim = sim
      bestEntry = e
    }
  }
  if (bestEntry && bestSim >= 0.65) {
    return {
      translated: bestEntry.text[target],
      confidence: Math.min(0.97, 0.6 + bestSim * 0.4),
      method: 'memory',
    }
  }

  // 2) phrase-based statistical model (longest match first, word argmax
  //    fallback), non-English pairs pivot through English
  return translatePivot(text, src, target)
}

function translateSegment(words, from, to) {
  const out = []
  let evidenced = 0
  let content = 0
  for (let i = 0; i < words.length; i++) {
    const w = words[i]
    const stop = from === 'en' ? STOPWORDS.has(w) : STOPWORDS_NONLATIN.has(w)
    if (stop) continue
    content++
    let matched = false
    for (const n of [3, 2]) {
      if (i + n > words.length) continue
      const p = words.slice(i, i + n).join(' ')
      const tbl = PHRASES[`${from}|${to}|${n}`]
      if (tbl && tbl.has(p)) {
        evidenced += n
        out.push(tbl.get(p).phrase)
        i += n - 1
        matched = true
        break
      }
    }
    if (!matched) {
      const r = translateWordPivot(w, from, to)
      if (r.evidence) evidenced++
      out.push(r.word)
    }
  }
  return {
    text: out.join(' '),
    confidence: content ? evidenced / content : 0,
    content,
  }
}

function translatePivot(text, src, target) {
  if (src === 'en' || target === 'en') {
    const r = translateSegment(tokenize(text, src), src, target)
    return { translated: r.text, confidence: r.confidence, method: 'statistical-ml' }
  }
  // two-stage via English pivot
  const mid = translateSegment(tokenize(text, src), src, 'en')
  const fin = translateSegment(tokenize(mid.text, 'en'), 'en', target)
  const confidence =
    (mid.confidence * fin.confidence) || 0
  return { translated: fin.text, confidence, method: 'statistical-ml' }
}

// ======================================================= ML: TF-IDF summary

const POS_LEX = {
  en: new Set(['good', 'great', 'excellent', 'fast', 'quickly', 'quick', 'professional', 'skilled', 'fair', 'recommended', 'satisfied', 'beautiful', 'quality', 'punctual', 'polite', 'friendly', 'careful', 'on', 'time', 'perfectly', 'neat', 'shine', 'bright', 'green', 'fresh', 'thank', 'highly']),
  ur: new Set(['اچھا', 'اچھی', 'بہترین', 'بہت', 'مہارت', 'پیشہ', 'ورانہ', 'مناسب', 'تیزی', 'وقت', 'مطمئن', 'خوبصورت', 'معیاری', 'شکریہ', 'دوست', 'مؤدب', 'احتیاط', 'روشن', 'سبز', 'تازہ', 'زبردست', 'مؤثر', 'ہمواری']),
  fr: new Set(['bon', 'excellent', 'très', 'rapidement', 'ponctuel', 'soigneux', 'professionnel', 'habile', 'juste', 'raisonnable', 'recommandé', 'satisfait', 'magnifique', 'qualité', 'amical', 'poli', 'clairement', 'lumineux', 'vert', 'fraîche', 'merci', 'parfaitement']),
  hi: new Set(['अच्छा', 'अच्छी', 'उत्कृष्ट', 'बहुत', 'हूनरमंद', 'पेशेवर', 'उचित', 'तेज़ी', 'समय', 'संतुष्ट', 'खूबसूरत', 'गुणवत्ता', 'धन्यवाद', 'दोस्ताना', 'शिष्ट', 'सावधान', 'स्पष्ट', 'रोशन', 'हरा', 'ताज़ा', 'सुचारू']),
}
const NEG_LEX = {
  en: new Set(['late', 'delayed', 'delay', 'slow', 'slowly', 'expensive', 'poor', 'problem', 'issue', 'bad', 'broken', 'leak', 'leaked', 'refuse', 'refused']),
  ur: new Set(['دیر', 'مہنگا', 'مسئلہ', 'آہستہ', 'بری', 'خراب']),
  fr: new Set(['retard', 'tardif', 'cher', 'mauvais', 'lent', 'problème']),
  hi: new Set(['देर', 'महँगा', 'समस्या', 'धीरे', 'बुरा', 'खराब']),
}

const LEAD = {
  en: (name, avg, n) => `Overall, customers rate ${name} ${avg}/5 across ${n} reviews.`,
  ur: (name, avg, n) => `کل طور پر، گاہکوں نے ${name} کو ${n} جائزوں میں ${avg}/5 درجہ دیا ہے۔`,
  fr: (name, avg, n) => `Dans l'ensemble, les clients notent ${name} ${avg}/5 sur ${n} avis.`,
  hi: (name, avg, n) => `सामान्य रूप से, ग्राहकों ने ${n} समीक्षाओं में ${name} को ${avg}/5 रेट किया है।`,
}

function summarize({ workerName, reviews, target }) {
  const n = reviews.length
  if (n === 0) return { paragraphs: [], method: 'tf-idf-extractive', count: 0 }

  const avg = (reviews.reduce((s, r) => s + r.rating, 0) / n).toFixed(1)
  const lead = (LEAD[target] || LEAD.en)(workerName, avg, n)

  // bring every review into the target language (already there -> keep)
  const texts = reviews.map((r) => {
    if (r.lang === target) return { text: r.text, lang: target }
    const t = translate(r.text, r.lang, target)
    return { text: t.translated, lang: target }
  })

  // split into sentences (each review may hold 1-2)
  const sentences = []
  for (const t of texts) {
    const parts = t.text.split(/(?<=[।.!؟?])/).map((s) => s.trim()).filter(Boolean)
    for (const s of parts) if (s.length > 2) sentences.push({ s, rating: t.rating })
  }

  // TF-IDF
  const docs = sentences.map((x) => tokenize(x.s, target))
  const df = {}
  for (const d of docs) {
    for (const w of new Set(d)) df[w] = (df[w] || 0) + 1
  }
  const N = docs.length
  const scoreDoc = (d) => {
    const tf = {}
    for (const w of d) tf[w] = (tf[w] || 0) + 1
    let score = 0
    for (const w of new Set(d)) {
      const idf = Math.log(1 + N / (df[w] || 1))
      score += tf[w] * idf
    }
    return score / Math.sqrt(d.length || 1)
  }
  const scored = sentences.map((x, i) => ({ ...x, score: scoreDoc(docs[i]), i }))

  const lex = POS_LEX[target] || POS_LEX.en
  const negLex = NEG_LEX[target] || NEG_LEX.en
  const isNeg = (s) => tokenize(s, target).some((w) => negLex.has(w))
  const isPos = (s) => tokenize(s, target).some((w) => lex.has(w))

  const twoParas = n > 4

  const picked = new Set()
  const pick = (pred, k) => {
    const cands = scored.filter((x) => !picked.has(x.i) && (!pred || pred(x)))
    cands.sort((a, b) => b.score - a.score)
    const take = cands.slice(0, k)
    take.forEach((x) => picked.add(x.i))
    return take
  }

  const p1count = twoParas ? 3 : 2
  let p1 = pick((x) => isPos(x.s) || !isNeg(x.s), p1count)
  if (p1.length < p1count) p1 = p1.concat(pick(null, p1count - p1.length))
  p1.sort((a, b) => a.i - b.i)

  let p2 = []
  if (twoParas) {
    p2 = pick(isNeg, 2)
    if (p2.length < 2) p2 = p2.concat(pick(null, 2 - p2.length))
    p2.sort((a, b) => a.i - b.i)
  }

  const join = (arr) => arr.map((x) => x.s).join(' ')
  const paragraphs = [lead + ' ' + join(p1)]
  if (twoParas) paragraphs.push(join(p2))

  return {
    paragraphs,
    method: 'tf-idf-extractive',
    count: n,
    sentencesUsed: paragraphs.length,
  }
}

// ================================================================ seed data

function daysAgo(n) {
  return new Date(Date.now() - n * 86400000).toISOString()
}

function makeJobs(workerId, titles, count, spanDays, extraOld = 0) {
  const jobs = []
  for (let i = 0; i < count; i++) {
    const t = titles[i % titles.length]
    jobs.push({
      id: `${workerId}-j${i + 1}`,
      workerId,
      title: t.title,
      category: t.cat,
      budgetMin: 800 + (i % 7) * 250,
      budgetMax: 2000 + (i % 7) * 500,
      rating: i % 4 === 0 ? 4 : 5,
      status: 'completed',
      completedAt: daysAgo(2 + Math.floor((i / count) * spanDays)),
    })
  }
  for (let i = 0; i < extraOld; i++) {
    const t = titles[i % titles.length]
    jobs.push({
      id: `${workerId}-old${i + 1}`,
      workerId,
      title: t.title,
      category: t.cat,
      budgetMin: 900,
      budgetMax: 2200,
      rating: 4,
      status: 'completed',
      completedAt: daysAgo(420 + i * 30),
    })
  }
  return jobs
}

const T = {
  pipe: [
    { title: 'Kitchen sink leak', cat: 'Plumbing' },
    { title: 'Bathroom faucet', cat: 'Plumbing' },
    { title: 'Water heater repair', cat: 'Plumbing' },
    { title: 'Pipe replacement', cat: 'Plumbing' },
  ],
  elec: [
    { title: 'Ceiling fan installation', cat: 'Electrical' },
    { title: 'AC wiring', cat: 'Electrical' },
    { title: 'Switch board replacement', cat: 'Electrical' },
    { title: 'Inverter installation', cat: 'Electrical' },
    { title: 'Socket replacement', cat: 'Electrical' },
  ],
  appliance: [
    { title: 'Refrigerator repair', cat: 'Appliance Repair' },
    { title: 'Washing machine service', cat: 'Appliance Repair' },
    { title: 'AC repair', cat: 'Appliance Repair' },
    { title: 'Microwave repair', cat: 'Appliance Repair' },
  ],
  mixed: [
    { title: 'Deep clean', cat: 'Cleaning' },
    { title: 'Painting touch-up', cat: 'Painting' },
    { title: 'Lawn trimming', cat: 'Gardening' },
    { title: 'Door lock change', cat: 'Carpentry' },
  ],
}

function worker(uid, fullName, professions, languages, about, jobs, reviews, activeJobs) {
  return { uid, fullName, professions, languages, about, jobs, reviews, activeJobs }
}

const WORKERS = [
  worker(
    'w-ahmed', 'Ahmed Raza', ['Plumbing', 'Electrical'], ['Urdu', 'English'],
    'Plumber with 6 years of experience. Always on time.',
    makeJobs('w-ahmed', T.pipe, 2, 120),
    [
      { id: 'r-a1', rating: 4, lang: 'ur', text: 'مناسب قیمت اور معقول رویہ۔', translations: { en: 'Fair price and reasonable attitude.' } },
      { id: 'r-a2', rating: 5, lang: 'en', text: 'Good work but he was a bit late.', translations: { ur: 'کام اچھا تھا لیکن تھوڑا دیر سے آیا۔' } },
    ],
    [{ id: 'aj-a1', title: 'Bathroom leak check', cat: 'Plumbing', status: 'assigned', createdAt: daysAgo(2) }],
  ),
  worker(
    'w-imran', 'Imran Khan', ['Plumbing', 'Electrical'], ['Urdu', 'English'],
    'Plumber with 8 years of experience.',
    makeJobs('w-imran', T.mixed.concat(T.pipe), 160, 360, 12),
    [
      { id: 'r-i1', rating: 5, lang: 'ur', text: 'کام بہت اچھا ہے۔ اس نے کام وقت پر مکمل کیا۔', translations: { en: 'The work is very good. He completed the job on time.' } },
      { id: 'r-i2', rating: 5, lang: 'en', text: 'The electrician is very skilled. Highly recommended.', translations: { ur: 'برقی فنی بہت مہارت رکھتا ہے۔ زبردست سفارش۔' } },
      { id: 'r-i3', rating: 4.5, lang: 'fr', text: 'Travail de qualité à prix juste. Il est ponctuel et soigneux.', translations: { en: 'Quality work at fair price. He is punctual and careful.' } },
      { id: 'r-i4', rating: 5, lang: 'hi', text: 'काम बहुत अच्छा है। उसने काम समय पर पूरा किया।', translations: { en: 'Very good work. He completed the job on time.' } },
      { id: 'r-i5', rating: 4, lang: 'en', text: 'Good work but he was a bit late. Fair price and good result.', translations: {} },
      { id: 'r-i6', rating: 5, lang: 'ur', text: 'پیشہ ورانہ رویہ۔ بہترین سروس۔', translations: { en: 'Professional attitude. Excellent service.' } },
      { id: 'r-i7', rating: 4.5, lang: 'fr', text: 'Le plombier a réparé la fuite rapidement.', translations: { en: 'The plumber fixed the leak quickly.' } },
      { id: 'r-i8', rating: 5, lang: 'hi', text: 'उसने हर चीज़ स्पष्ट रूप से समझाई। पेशेवर रविया।', translations: { en: 'He explained everything clearly. Professional attitude.' } },
      { id: 'r-i9', rating: 3.5, lang: 'en', text: 'The repair took two hours and he arrived late.', translations: {} },
      { id: 'r-i10', rating: 5, lang: 'ur', text: 'میں اسے دوبارہ ضرور لیا کروں گا۔', translations: { en: 'I will definitely hire him again.' } },
      { id: 'r-i11', rating: 4, lang: 'hi', text: 'मौसम अच्छा था लेकिन थोड़ा देर से आया।', translations: { en: 'Work was good but arrived a bit late.' } },
      { id: 'r-i12', rating: 5, lang: 'en', text: 'Excellent service. On time and within budget.', translations: { ur: 'بہترین سروس۔ وقت پر اور بجٹ کے اندر۔' } },
    ],
    [{ id: 'aj-i1', title: 'Kitchen pipe burst', cat: 'Plumbing', status: 'inProgress', createdAt: daysAgo(1) }],
  ),
  worker(
    'w-faisal', 'Faisal Mehmood', ['Electrical', 'Appliance Repair'], ['Urdu', 'English', 'Punjabi'],
    'Certified electrician. AC and inverter specialist.',
    makeJobs('w-faisal', T.elec, 320, 360),
    [
      { id: 'r-f1', rating: 5, lang: 'en', text: 'The fan is working perfectly now. Very skilled.', translations: {} },
      { id: 'r-f2', rating: 4.5, lang: 'ur', text: 'وائرنگ محفوظ طریقے سے کی گئی۔ اچھا تخمینہ۔', translations: { en: 'Wiring done safely. Good quote.' } },
      { id: 'r-f3', rating: 5, lang: 'hi', text: 'पंखा अब पूरी तरह चल रहा है। बहुत हुनरमंद।', translations: { en: 'The fan is working perfectly now. Very skilled.' } },
      { id: 'r-f4', rating: 4, lang: 'en', text: 'The AC is cooling well now. He explained everything clearly.', translations: {} },
      { id: 'r-f5', rating: 5, lang: 'fr', text: "Le tableau électrique a été remplacé. Travail propre.", translations: { en: 'The switch board was replaced. Neat work.' } },
    ],
    [{ id: 'aj-f1', title: 'Inverter not charging', cat: 'Electrical', status: 'assigned', createdAt: daysAgo(3) }],
  ),
  worker(
    'w-bilal', 'Bilal Khan', ['Appliance Repair', 'Electrical'], ['Urdu', 'English'],
    'AC, fridge and washing machine specialist. 10 years experience.',
    makeJobs('w-bilal', T.appliance, 470, 360),
    [
      { id: 'r-b1', rating: 5, lang: 'ur', text: 'فریج جلدی ٹھیک کر دیا گیا۔ معیاری کام۔', translations: { en: 'The fridge was repaired quickly. Quality work.' } },
      { id: 'r-b2', rating: 4.5, lang: 'en', text: 'The washing machine runs smoothly now.', translations: {} },
      { id: 'r-b3', rating: 5, lang: 'hi', text: 'एसी अब अच्छी तरह ठंडक दे रहा है। उत्कृष्ट सेवा।', translations: { en: 'The AC is cooling well now. Excellent service.' } },
      { id: 'r-b4', rating: 4, lang: 'en', text: 'He arrived late but the repair was good and fast after that.', translations: {} },
      { id: 'r-b5', rating: 5, lang: 'ur', text: 'دھوبی مشین ہمواری سے چل رہی ہے۔ شکریہ۔', translations: { en: 'The washing machine runs smoothly. Thanks.' } },
      { id: 'r-b6', rating: 4.5, lang: 'fr', text: "La climatisation refroidit bien maintenant. Technicien poli.", translations: { en: 'The AC is cooling well now. Polite technician.' } },
    ],
    [],
  ),
  worker(
    'w-zain', 'Zain Malik', ['Electrical', 'Appliance Repair'], ['Urdu', 'English', 'Punjabi'],
    'Certified electrician. AC, fridge, washing machine specialist.',
    makeJobs('w-zain', T.elec.concat(T.appliance), 640, 360),
    [
      { id: 'r-z1', rating: 5, lang: 'en', text: 'Excellent service, very professional. On time and within budget.', translations: { ur: 'بہترین سروس، بہت پیشہ ورانہ۔ وقت پر اور بجٹ کے اندر۔' } },
      { id: 'r-z2', rating: 5, lang: 'ur', text: "بہترین کام، دوبارہ ضرور لیا جائے گا", translations: { en: 'Excellent work, will definitely hire again.' } },
      { id: 'r-z3', rating: 5, lang: 'en', text: 'The motor was rewired by an expert. Highly recommended.', translations: {} },
      { id: 'r-z4', rating: 4.5, lang: 'hi', text: 'वायरिंग सुरक्षित तरीके से की गई। अच्छा अनुमान।', translations: { en: 'Wiring done safely. Good quote.' } },
      { id: 'r-z5', rating: 5, lang: 'fr', text: "L'éclairage est lumineux. Travail soigneux.", translations: { en: 'The lighting is bright. Careful work.' } },
      { id: 'r-z6', rating: 4, lang: 'en', text: 'He arrived late but finished the job well.', translations: {} },
      { id: 'r-z7', rating: 5, lang: 'ur', text: 'موتور کو ماہر نے دوبارہ وائر کیا۔ زبردست سفارش۔', translations: { en: 'The motor was rewired by an expert. Highly recommended.' } },
      { id: 'r-z8', rating: 4.5, lang: 'hi', text: 'लाइटिंग का नक्शा रोशन है। सावधानी वाला काम।', translations: { en: 'The lighting layout is bright. Careful work.' } },
    ],
    [{ id: 'aj-z1', title: 'AC gas refill', cat: 'Appliance Repair', status: 'assigned', createdAt: daysAgo(1) }],
  ),
]

// ================================================================ language API

function loadCollection() {
  return JSON.parse(fs.readFileSync(COLLECTION_FILE, 'utf8'))
}

function loadProxy() {
  return JSON.parse(fs.readFileSync(PROXY_FILE, 'utf8'))
}

function mergedLanguages() {
  const merged = new Map()
  for (const l of loadCollection()) {
    merged.set(l.code, { ...l, source: 'collection' })
  }
  for (const p of loadProxy()) {
    if (!merged.has(p.code)) {
      merged.set(p.code, {
        code: p.code,
        nativeName: p.nativeName || p.code,
        englishName: p.englishName || p.code,
        source: 'proxy',
      })
    } else {
      merged.get(p.code).source = 'collection+proxy'
    }
  }
  return [...merged.values()].sort((a, b) => a.englishName.localeCompare(b.englishName))
}

// ================================================================ server

function sendJson(res, code, obj) {
  const body = JSON.stringify(obj)
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
  })
  res.end(body)
}

function readBody(req) {
  return new Promise((resolve) => {
    let data = ''
    req.on('data', (c) => (data += c))
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {})
      } catch {
        resolve({})
      }
    })
  })
}

function workerPayload(w) {
  const completed = w.jobs.slice().sort((a, b) => new Date(b.completedAt) - new Date(a.completedAt))
  const yearAgo = Date.now() - 365 * 86400000
  const jobsInYear = completed.filter((j) => new Date(j.completedAt).getTime() >= yearAgo).length
  const rating = w.reviews.length
    ? w.reviews.reduce((s, r) => s + r.rating, 0) / w.reviews.length
    : 0
  return {
    uid: w.uid,
    fullName: w.fullName,
    professions: w.professions,
    languages: w.languages,
    rating: Math.round(rating * 10) / 10,
    about: w.about,
    completedJobs: completed.length,
    jobsInYear,
    reviews: w.reviews.map((r) => ({
      id: r.id,
      rating: r.rating,
      lang: r.lang,
      text: r.text,
      translations: r.translations,
    })),
    jobs: completed,
    activeJobs: w.activeJobs,
    isAvailable: true,
  }
}

const corpus = JSON.parse(fs.readFileSync(CORPUS_FILE, 'utf8'))
trainSMT(corpus)
buildTM(corpus)
buildPhrases(corpus)

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`)

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    })
    return res.end()
  }

  try {
    if (url.pathname === '/' || url.pathname === '/index.html') {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' })
      return res.end(fs.readFileSync(path.join(__dirname, 'index.html')))
    }

    if (url.pathname === '/api/languages' && req.method === 'GET') {
      return sendJson(res, 200, mergedLanguages())
    }

    if (url.pathname === '/api/languages' && req.method === 'POST') {
      const { code, nativeName, englishName } = await readBody(req)
      if (!code || !englishName) {
        return sendJson(res, 400, { error: 'code and englishName required' })
      }
      const collection = loadCollection()
      if (!collection.some((l) => l.code === code)) {
        collection.push({ code, nativeName: nativeName || code, englishName })
        fs.writeFileSync(COLLECTION_FILE, JSON.stringify(collection, null, 2))
      }
      return sendJson(res, 200, { ok: true, languages: mergedLanguages() })
    }

    if (url.pathname === '/api/workers' && req.method === 'GET') {
      return sendJson(res, 200, WORKERS.map(workerPayload))
    }

    if (url.pathname === '/api/ml/report' && req.method === 'GET') {
      return sendJson(res, 200, {
        corpusSentences: corpus.length,
        languages: LANGS,
        wordAlignments: alignmentCount,
        distinctPairs: tableSize(),
        phraseEntries: phraseCount(),
        tmEntries: TM.length,
        pivot: 'English',
      })
    }

    if (url.pathname === '/api/translate' && req.method === 'POST') {
      const { text, target, source } = await readBody(req)
      if (!text || !target) {
        return sendJson(res, 400, { error: 'text and target required' })
      }
      // infer source: find the corpus language whose tokens overlap most
      let best = 'en'
      let bestScore = 0
      for (const code of LANGS) {
        const toks = new Set(tokenize(text, code))
        let score = 0
        for (const e of TM) {
          const ref = new Set((e.norm[code] || '').split(' '))
          for (const t of toks) if (ref.has(t)) score++
        }
        if (score > bestScore) {
          bestScore = score
          best = code
        }
      }
      const out = translate(text, best, target)
      return sendJson(res, 200, { ...out, source: best })
    }

    if (url.pathname === '/api/summarize' && req.method === 'POST') {
      const { workerName, reviews, target } = await readBody(req)
      if (!reviews || !Array.isArray(reviews)) {
        return sendJson(res, 400, { error: 'reviews array required' })
      }
      const out = summarize({ workerName: workerName || 'the worker', reviews, target: target || 'en' })
      return sendJson(res, 200, out)
    }

    if (url.pathname === '/api/reviews' && req.method === 'POST') {
      const { workerId, rating, text, lang } = await readBody(req)
      const w = WORKERS.find((x) => x.uid === workerId)
      if (!w || !text || !rating) {
        return sendJson(res, 400, { error: 'workerId, rating and text required' })
      }
      const review = {
        id: `r-${Date.now()}`,
        rating,
        lang: lang || 'en',
        text,
        translations: {},
      }
      w.reviews.unshift(review)
      return sendJson(res, 200, { ok: true, worker: workerPayload(w) })
    }

    if (url.pathname === '/api/jobs/complete' && req.method === 'POST') {
      const { jobId } = await readBody(req)
      for (const w of WORKERS) {
        const aj = w.activeJobs.find((j) => j.id === jobId)
        if (aj) {
          aj.status = 'completed'
          w.activeJobs = w.activeJobs.filter((j) => j.id !== jobId)
          w.jobs.push({
            id: aj.id,
            workerId: w.uid,
            title: aj.title,
            category: aj.cat,
            budgetMin: 1000,
            budgetMax: 2500,
            rating: null,
            status: 'completed',
            completedAt: new Date().toISOString(),
          })
          return sendJson(res, 200, { ok: true, worker: workerPayload(w) })
        }
      }
      return sendJson(res, 404, { error: 'job not found' })
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' })
    res.end('not found')
  } catch (err) {
    sendJson(res, 500, { error: err.message })
  }
})

server.listen(PORT, '0.0.0.0', () => {
  console.log(`QuickFix demo listening on :${PORT}`)
  console.log(
    `SMT trained: ${corpus.length} sentences | ${alignmentCount} word alignments | ${tableSize()} distinct word pairs | ${phraseCount()} phrase entries | ${TM.length} memory entries`,
  )
})
