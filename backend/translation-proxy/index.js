// Translation proxy: POST /translate with { q, target } -> { translated }
// Server-side Cloud Translation API call; key never shipped to clients.
const express = require('express')
const { Translate } = require('@google-cloud/translate').v2

const app = express()
app.use(express.json())

const API_KEY = process.env.GOOGLE_TRANSLATE_API_KEY
const PORT = process.env.PORT || 8080

const translate = API_KEY ? new Translate({ key: API_KEY }) : null

app.get('/health', (_req, res) => {
  res.json({ ok: true })
})

// GET /languages -> [{ code, nativeName }]
// Dynamic list of languages the translation engine supports (Google Cloud
// Translation). The app merges this with the admin-curated `languages`
// collection in Firestore, so the sign-up language picker is never
// hard-coded in the client.
app.get('/languages', async (_req, res) => {
  if (!translate) {
    return res.status(503).json({ error: 'GOOGLE_TRANSLATE_API_KEY not configured' })
  }
  try {
    const languages = await translate.getLanguages()
    res.json(
      languages.map((l) => ({
        code: l.languageCode,
        nativeName: l.nativeName,
      })),
    )
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

app.post('/translate', async (req, res) => {
  const { q, target = 'en' } = req.body || {}
  if (!q || typeof q !== 'string') {
    return res.status(400).json({ error: 'Missing "q"' })
  }
  if (!translate) {
    return res.status(503).json({ error: 'GOOGLE_TRANSLATE_API_KEY not configured' })
  }
  try {
    const [translated] = await translate.translate(q, target)
    res.json({ translated })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// ========================================================= summarization
// POST /summarize with { workerName, reviews: [{text, lang, rating}], target }
// -> { paragraphs: [..], method, count }
//
// Extractive ML summary: every review is brought into the target language
// (neural MT when the key is configured), split into sentences, scored with
// TF-IDF plus sentiment lexicons, and the top sentences are emitted —
// 1 paragraph for <=4 reviews, 2 paragraphs for more.

const STOP = new Set([
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'of', 'and', 'or', 'to',
  'in', 'on', 'at', 'it', 'he', 'she', 'they', 'i', 'you', 'we', 'my',
  'your', 'for', 'with', 'this', 'that', 'now', 'very', 'but', 'not',
  'ہے', 'ہیں', 'تھا', 'ہو', 'اور', 'کی', 'کا', 'کے', 'کو', 'سے', 'پر', 'یہ', 'وہ', 'میں', 'اس',
  'le', 'la', 'les', 'est', 'et', 'de', 'des', 'un', 'une', 'il', 'elle',
  'très', 'dans', 'pour', 'par', 'a', 'au', 'aux', 'du', 'que',
  'है', 'हैं', 'था', 'और', 'का', 'की', 'के', 'को', 'से', 'पर', 'यह', 'वह', 'में', 'इस',
])
const RTL = new Set(['ur', 'ar', 'fa', 'ps', 'sd'])

function tokenize(text, lang) {
  const rtl = RTL.has(lang)
  let t = String(text).toLowerCase()
  t = t.replace(rtl ? /[،。؟?!،؛;.,:]/g : /[.,!?;:'’-]+/g, ' ')
  return t.split(/\s+/).filter((w) => w && !STOP.has(w))
}

const POS = {
  en: new Set(['good', 'great', 'excellent', 'fast', 'quickly', 'quick', 'professional', 'skilled', 'fair', 'recommended', 'satisfied', 'beautiful', 'quality', 'punctual', 'polite', 'friendly', 'careful', 'on', 'time', 'perfectly', 'neat', 'bright', 'fresh', 'thank', 'highly']),
  ur: new Set(['اچھا', 'اچھی', 'بہترین', 'بہت', 'مہارت', 'پیشہ', 'مناسب', 'تیزی', 'وقت', 'مطمئن', 'خوبصورت', 'معیاری', 'شکریہ', 'دوست', 'مؤدب', 'احتیاط', 'روشن', 'سبز', 'تازہ', 'زبردست', 'مؤثر', 'ہمواری']),
  fr: new Set(['bon', 'excellent', 'très', 'rapidement', 'ponctuel', 'soigneux', 'professionnel', 'habile', 'juste', 'raisonnable', 'recommandé', 'satisfait', 'magnifique', 'qualité', 'amical', 'poli', 'lumineux', 'vert', 'fraîche', 'merci', 'parfaitement']),
  hi: new Set(['अच्छा', 'अच्छी', 'उत्कृष्ट', 'बहुत', 'हुनरमंद', 'पेशेवर', 'उचित', 'तेज़ी', 'समय', 'संतुष्ट', 'खूबसूरत', 'गुणवत्ता', 'धन्यवाद', 'दोस्ताना', 'शिष्ट', 'सावधान', 'स्पष्ट', 'रोशन', 'हरा', 'ताज़ा', 'सुचारू']),
}
const NEG = {
  en: new Set(['late', 'delayed', 'delay', 'slow', 'slowly', 'expensive', 'poor', 'problem', 'issue', 'bad', 'broken', 'leak', 'leaked', 'refuse', 'refused']),
  ur: new Set(['دیر', 'مہنگا', 'مسئلہ', 'آہستہ', 'بری', 'خراب']),
  fr: new Set(['retard', 'tardif', 'cher', 'mauvais', 'lent', 'problème']),
  hi: new Set(['देर', 'महँगा', 'समस्या', 'धीरे', 'बुरा', 'खराब']),
}
const LEAD = {
  en: (name, avg, n) => `Overall, customers rate ${name} ${avg}/5 across ${n} reviews.`,
  ur: (name, avg, n) => `کل طور پر، گاہکوں نے ${name} کو ${n} جائزوں میں ${avg}/5 درجہ دیا ہے۔`,
  fr: (name, avg, n) => `Dans l’ensemble, les clients notent ${name} ${avg}/5 sur ${n} avis.`,
  hi: (name, avg, n) => `सामान्य रूप से, ग्राहकों ने ${n} समीक्षाओं में ${name} को ${avg}/5 रेट किया है।`,
}

function summarizeReviews({ workerName, texts, target }) {
  const n = texts.length
  if (n === 0) return { paragraphs: [], method: 'tf-idf-extractive', count: 0 }
  const avg = (texts.reduce((s, r) => s + (r.rating || 5), 0) / n).toFixed(1)
  const lead = (LEAD[target] || LEAD.en)(workerName, avg, n)

  const sentences = []
  for (const t of texts) {
    for (const s of t.text.split(/(?<=[।.!؟?])/).map((x) => x.trim()).filter((x) => x.length > 2)) {
      sentences.push({ s, rating: t.rating })
    }
  }
  const docs = sentences.map((x) => tokenize(x.s, target))
  const df = {}
  for (const d of docs) for (const w of new Set(d)) df[w] = (df[w] || 0) + 1
  const N = docs.length
  const scoreDoc = (d) => {
    const tf = {}
    for (const w of d) tf[w] = (tf[w] || 0) + 1
    let score = 0
    for (const w of new Set(d)) score += tf[w] * Math.log(1 + N / (df[w] || 1))
    return score / Math.sqrt(d.length || 1)
  }
  const scored = sentences.map((x, i) => ({ ...x, score: scoreDoc(docs[i]), i }))
  const lex = POS[target] || POS.en
  const negLex = NEG[target] || NEG.en
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
  return { paragraphs, method: 'tf-idf-extractive', count: n }
}

app.post('/summarize', async (req, res) => {
  const { workerName, reviews, target = 'en' } = req.body || {}
  if (!Array.isArray(reviews) || reviews.length === 0) {
    return res.status(400).json({ error: 'Missing "reviews" array' })
  }
  try {
    let texts
    if (translate) {
      // neural MT: bring every review into the target language first
      texts = await Promise.all(
        reviews.map(async (r) => {
          if (r.lang === target) return { text: r.text, rating: r.rating }
          try {
            const [t] = await translate.translate(r.text, target)
            return { text: t, rating: r.rating }
          } catch {
            return { text: r.text, rating: r.rating }
          }
        }),
      )
    } else {
      // no key: summarize reviews already in the target language
      texts = reviews.filter((r) => r.lang === target)
      if (!texts.length) texts = reviews
    }
    res.json(summarizeReviews({ workerName: workerName || 'the worker', texts, target }))
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

app.listen(PORT, () => {
  console.log(`Translation proxy listening on :${PORT}`)
})
