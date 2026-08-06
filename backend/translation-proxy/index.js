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

app.listen(PORT, () => {
  console.log(`Translation proxy listening on :${PORT}`)
})
