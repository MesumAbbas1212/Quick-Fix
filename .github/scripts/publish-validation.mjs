import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

// Public test diagnostics only; no production Firebase credentials. Check Run
// annotations make each failure available over api.github.com even when the
// caller cannot download GitHub's separately hosted log/artifact blobs.
const env = process.env
const directory = env.VALIDATION_DIR
const kind = env.VALIDATION_KIND || 'validation'
const outcomes = Object.fromEntries(Object.entries(env).filter(([key]) => key.startsWith('VALIDATION_') && !['VALIDATION_DIR', 'VALIDATION_KIND'].includes(key)))
function read(name) {
  const filename = path.join(directory, name)
  return fs.existsSync(filename) ? fs.readFileSync(filename, 'utf8') : '(not produced)'
}
function bounded(value, maximum = 48000) {
  const bytes = Buffer.from(value)
  if (bytes.length <= maximum) return value
  const half = Math.floor(maximum / 2) - 100
  return bytes.subarray(0, half).toString('utf8') + '\n… middle omitted; full log in artifact …\n' + bytes.subarray(-half).toString('utf8')
}
function parseFlutter(log) {
  const tests = new Map(), suites = new Map(), done = new Map(), errors = new Map(), prints = new Map()
  let result
  for (const line of log.split('\n')) {
    let event
    try { event = JSON.parse(line) } catch { continue }
    if (event.type === 'suite') suites.set(event.suite.id, event.suite)
    if (event.type === 'testStart') tests.set(event.test.id, event.test)
    if (event.type === 'testDone') done.set(event.testID, event)
    if (event.type === 'error') errors.set(event.testID, [...(errors.get(event.testID) || []), `${event.error}\n${event.stackTrace || ''}`])
    if (event.type === 'print') prints.set(event.testID, [...(prints.get(event.testID) || []), event.message])
    if (event.type === 'done') result = event
  }
  const counts = { passed: 0, failed: 0, skipped: 0 }
  const annotations = []
  for (const [id, event] of done) {
    if (event.hidden) continue
    if (event.skipped) { counts.skipped++; continue }
    if (event.result === 'success') { counts.passed++; continue }
    counts.failed++
    const test = tests.get(id) || { name: `Test ${id}` }
    let filename = test.root_url || suites.get(test.suiteID)?.path || test.url || ''
    if (filename.startsWith('file:')) filename = fileURLToPath(filename)
    const relative = filename ? path.relative(env.GITHUB_WORKSPACE || process.cwd(), filename) : '.github/workflows/validate.yml'
    annotations.push({ path: relative, start_line: test.line || test.root_line || 1, end_line: test.line || test.root_line || 1, annotation_level: 'failure',
      title: bounded(test.name, 240), message: bounded(`${test.name}\n\n${(prints.get(id) || []).join('\n')}\n${(errors.get(id) || []).join('\n')}`, 45000) })
  }
  return { result, counts, annotations }
}
const testsLog = read('tests.log')
const flutter = kind === 'mobile' ? parseFlutter(testsLog) : undefined
const success = Object.values(outcomes).length > 0 && Object.values(outcomes).every(value => value === 'success') && (!flutter || flutter.result?.success === true)
const files = fs.existsSync(directory) ? fs.readdirSync(directory).filter(name => name.endsWith('.log')).sort() : []
const versions = files.filter(name => !['tests.log', 'analyze.log'].includes(name)).map(name => `### ${name}\n\n\`\`\`text\n${bounded(read(name), 8000)}\n\`\`\``).join('\n')
let coverageText = ''
const coverageFile = path.join(env.GITHUB_WORKSPACE || process.cwd(), 'mobile/coverage/lcov.info')
if (kind === 'mobile' && fs.existsSync(coverageFile)) {
  let lines = 0, covered = 0
  for (const line of fs.readFileSync(coverageFile, 'utf8').split('\n')) {
    if (line.startsWith('LF:')) lines += Number(line.slice(3))
    if (line.startsWith('LH:')) covered += Number(line.slice(3))
  }
  coverageText = `\n${success ? 'Full-run' : 'Partial/failed-run'} line coverage: ${covered}/${lines} (${lines ? (covered * 100 / lines).toFixed(2) : 'unknown'}%).\n`
}
const countText = flutter ? `\nFlutter executed: ${flutter.counts.passed} passed; ${flutter.counts.failed} failed; ${flutter.counts.skipped} skipped. Machine completion: ${flutter.result?.success ?? 'missing'}.\n` : ''
const summary = `## ${kind}: ${success ? 'passed' : 'not passed'}\n\n${Object.entries(outcomes).map(([key, value]) => `- ${key}: ${value}`).join('\n')}\n${countText}${coverageText}\n${versions}\n\n### Analyze\n\n\`\`\`text\n${bounded(read('analyze.log'), 40000)}\n\`\`\``
const text = `### ${kind === 'admin' ? 'Build (not browser tests)' : 'Tests'}\n\n\`\`\`text\n${bounded(testsLog, 58000)}\n\`\`\``
const base = `https://api.github.com/repos/${env.GITHUB_REPOSITORY}/check-runs`
async function github(url, method, body) {
  const response = await fetch(url, { method, headers: { Authorization: `Bearer ${env.GH_TOKEN}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
  if (!response.ok) throw new Error(`Could not publish diagnostics: ${response.status} ${await response.text()}`)
  return await response.json()
}
const output = { title: `${kind} validation results (actual execution)`, summary: bounded(summary, 62000), text: bounded(text, 62000) }
const annotations = flutter?.annotations || []
const check = await github(base, 'POST', { name: `QuickFix ${kind} diagnostics`, head_sha: env.GITHUB_SHA, status: 'completed', conclusion: success ? 'success' : 'failure', output: { ...output, annotations: annotations.slice(0, 50) } })
for (let offset = 50; offset < annotations.length; offset += 50) {
  await github(`${base}/${check.id}`, 'PATCH', { output: { ...output, annotations: annotations.slice(offset, offset + 50) } })
}
console.log(`Published ${check.name}: ${check.conclusion}; check ${check.id}; ${annotations.length} detailed failure annotations`)
if (!success) process.exitCode = 1
