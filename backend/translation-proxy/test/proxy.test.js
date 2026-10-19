'use strict'
const { test } = require('node:test')
const assert = require('node:assert/strict')
const http = require('node:http')
const { createApp } = require('../index')

async function request(options, callback) {
  const server = http.createServer(createApp(options))
  await new Promise(resolve => server.listen(0, '0.0.0.0', resolve))
  const origin = `http://127.0.0.1:${server.address().port}`
  try { await callback(origin) }
  finally { await new Promise(resolve => { server.close(resolve); server.closeAllConnections() }) }
}
const post = (origin, route, body) => fetch(`${origin}${route}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })

test('Cloud Translation v2 language tuple is unwrapped into a dynamic catalog', async () => {
  await request({ translator: { getLanguages: async target => { assert.equal(target, 'en'); return [[{ code: 'ur', name: 'Urdu' }, { code: 'novel', name: 'Backend-added language' }], {}] } } }, async origin => {
    const response = await fetch(`${origin}/languages`)
    assert.equal(response.status, 200)
    assert.deepEqual(await response.json(), [{ code: 'ur', nativeName: '', englishName: 'Urdu' }, { code: 'novel', nativeName: '', englishName: 'Backend-added language' }])
  })
})
test('ASCII text reaches ML with the user-supplied target, not a fixed English/dictionary shortcut', async () => {
  await request({ translator: { translate: async (text, target) => { assert.equal(text, 'Great work'); assert.equal(target, 'ur'); return ['بہت اچھا کام', {}] } } }, async origin => {
    const response = await post(origin, '/translate', { q: 'Great work', target: 'ur' })
    assert.equal(response.status, 200); assert.deepEqual(await response.json(), { translated: 'بہت اچھا کام' })
  })
})
test('unconfigured provider fails explicitly without invented translations/languages', async () => {
  await request({ translator: null }, async origin => {
    assert.equal((await fetch(`${origin}/languages`)).status, 503)
    assert.equal((await post(origin, '/translate', { q: 'Great work', target: 'ur' })).status, 503)
  })
})
test('hung ML provider cannot hold an HTTP response indefinitely', async () => {
  await request({ translator: { translate: () => new Promise(() => {}) }, timeoutMs: 25 }, async origin => {
    const response = await post(origin, '/translate', { q: 'Great work', target: 'ur' })
    assert.equal(response.status, 504); assert.match((await response.json()).error, /timed out/)
  })
})
test('invalid input is rejected and raw provider errors/secrets are not returned', async () => {
  let calls = 0
  await request({ translator: { translate: async () => { calls++; throw new Error('private-provider-token-DO-NOT-LEAK') } } }, async origin => {
    assert.equal((await post(origin, '/translate', { q: '', target: 'ur' })).status, 400)
    assert.equal(calls, 0)
    const response = await post(origin, '/translate', { q: 'Great work', target: 'ur' })
    assert.equal(response.status, 502); assert.doesNotMatch(await response.text(), /DO-NOT-LEAK/)
  })
})
test('extractive summary contract remains one paragraph through four reviews, two above four', async () => {
  await request({ translator: null }, async origin => {
    const reviews = Array.from({ length: 5 }, (_, index) => ({ text: `Good careful work number ${index}. The job was completed professionally.`, lang: 'en', rating: 5 }))
    const small = await (await post(origin, '/summarize', { workerName: 'Demo', target: 'en', reviews: reviews.slice(0, 4) })).json()
    const large = await (await post(origin, '/summarize', { workerName: 'Demo', target: 'en', reviews })).json()
    assert.equal(small.paragraphs.length, 1); assert.equal(large.paragraphs.length, 2); assert.equal(large.method, 'tf-idf-extractive')
  })
})
test('summary translation uses the requested target and times out instead of hanging', async () => {
  let targetSeen
  await request({ translator: { translate: (_text, target) => { targetSeen = target; return new Promise(() => {}) } }, timeoutMs: 25 }, async origin => {
    const response = await post(origin, '/summarize', { workerName: 'Demo', target: 'novel', reviews: [{ text: 'Genuine original review', lang: 'und', rating: 5 }] })
    assert.equal(response.status, 504); assert.equal(targetSeen, 'novel')
  })
})
