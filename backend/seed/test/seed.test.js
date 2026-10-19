'use strict'
const { test } = require('node:test')
const assert = require('node:assert/strict')
const { spawnSync } = require('node:child_process')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { buildDataset, auditDataset, RANK_STEPS, APP_LANGUAGES, REVIEW_LANG_WEIGHTS } = require('../seed')
const now = Date.UTC(2026, 9, 19, 12)
const data = buildDataset({ now })
const audit = auditDataset(data, now)

test('fixture plan has many cities including Attock and all five real annual ranks', () => {
  assert.equal(data.workers.length, 49); assert.equal(audit.cities, 49); assert.ok(audit.attockNamedWorkers > 0)
  assert.equal(RANK_STEPS, 156); assert.ok(Object.values(audit.rankCounts).every(count => count > 0)); assert.deepEqual(audit.failures, [])
})
test('every worker has 100+ reviews and every configured corpus language, not just a weighted chance', () => {
  for (const worker of data.workers) {
    const reviews = data.reviews.filter(review => review.workerId === worker.uid)
    assert.ok(reviews.length >= 100)
    assert.deepEqual(new Set(reviews.map(review => review.originalLang)), new Set(REVIEW_LANG_WEIGHTS.map(([code]) => code)))
  }
})
test('Balochi uses ISO bal, not the distinct Brahui code brh', () => {
  assert.equal(APP_LANGUAGES.find(([, , english]) => english === 'Balochi')[0], 'bal')
  assert.ok(data.reviews.some(review => review.originalLang === 'bal'))
})
test('fixed-clock fixtures are deterministic and synthetic accounting remains finite', () => {
  assert.deepEqual(buildDataset({ now }), data)
  assert.ok(data.workers.every(worker => Number.isFinite(worker.rating) && worker.rating >= 1 && worker.rating <= 5))
  assert.ok(audit.estimatedDocumentWrites > 20000) // Warn operators: may exceed free-tier daily writes.
})
test('default CLI is a credential-free dry run; a small override cannot breach 100 reviews', () => {
  const result = spawnSync(process.execPath, [path.resolve(__dirname, '../seed.js'), '--dry-run'], { env: { ...process.env, REVIEWS_PER_WORKER: '10' }, encoding: 'utf8' })
  assert.equal(result.status, 0, result.stderr); const report = JSON.parse(result.stdout)
  assert.equal(report.minReviewsPerWorker, 100); assert.equal(report.liveWritesPerformed, false); assert.deepEqual(report.failures, [])
})
test('broad CLEAN collection deletion is rejected before Firebase initialization', () => {
  const result = spawnSync(process.execPath, [path.resolve(__dirname, '../seed.js'), '--write'], { env: { ...process.env, CLEAN: '1' }, encoding: 'utf8' })
  assert.equal(result.status, 1); assert.match(result.stderr, /Broad collection deletion is disabled/); assert.doesNotMatch(result.stderr, /not installed/)
})
test('operator corpus extends language coverage without app code changes or fake native translations', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'quickfix-corpus-'))
  try {
    const file = path.join(directory, 'fixture.json')
    // qaa is a private-use TEST fixture, not claimed as a Pakistani language.
    fs.writeFileSync(file, JSON.stringify([{ code: 'qaa', nativeName: 'Test language', englishName: 'Test language', templates: [['Test positive', 'Positive', 'pos'], ['Test neutral', 'Neutral', 'neu'], ['Test negative', 'Negative', 'neg']] }]))
    const result = spawnSync(process.execPath, [path.resolve(__dirname, '../seed.js'), '--dry-run'], { env: { ...process.env, SEED_REVIEW_CORPUS: file }, encoding: 'utf8' })
    assert.equal(result.status, 0, result.stderr); const report = JSON.parse(result.stdout); assert.ok(report.reviewLanguages.includes('qaa')); assert.deepEqual(report.failures, [])
  } finally { fs.rmSync(directory, { recursive: true, force: true }) }
})
