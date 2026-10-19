import fs from 'node:fs'
import path from 'node:path'

// GitHub-hosted runners fetch the SDK/emulators; the constrained agent can read
// this small Check Run over api.github.com without downloading artifact blobs.
// Only public test diagnostics are published. No live Firebase credentials used.
const env = process.env
const directory = env.VALIDATION_DIR
const kind = env.VALIDATION_KIND || 'validation'
const outcomes = Object.fromEntries(Object.entries(env).filter(([key]) => key.startsWith('VALIDATION_') && !['VALIDATION_DIR', 'VALIDATION_KIND'].includes(key)))
const success = Object.values(outcomes).length > 0 && Object.values(outcomes).every(value => value === 'success')
function read(name) {
  const filename = path.join(directory, name)
  return fs.existsSync(filename) ? fs.readFileSync(filename, 'utf8') : '(not produced)'
}
function bounded(value, maximum = 48000) {
  return value.length <= maximum ? value : value.slice(0, maximum / 2) + '\n… middle omitted; full log in artifact …\n' + value.slice(-maximum / 2)
}
const files = fs.existsSync(directory) ? fs.readdirSync(directory).filter(name => name.endsWith('.log')).sort() : []
const version = files.filter(name => !['tests.log', 'analyze.log'].includes(name)).map(name => `### ${name}\n\n\`\`\`text\n${bounded(read(name), 8000)}\n\`\`\``).join('\n')
const summary = `## ${kind}: ${success ? 'passed' : 'not passed'}\n\n${Object.entries(outcomes).map(([key, value]) => `- ${key}: ${value}`).join('\n')}\n\n${version}\n\n### Analyze\n\n\`\`\`text\n${bounded(read('analyze.log'), 42000)}\n\`\`\``
const text = `### Tests\n\n\`\`\`text\n${bounded(read('tests.log'), 60000)}\n\`\`\``
const response = await fetch(`https://api.github.com/repos/${env.GITHUB_REPOSITORY}/check-runs`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${env.GH_TOKEN}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'Content-Type': 'application/json' },
  body: JSON.stringify({ name: `QuickFix ${kind} diagnostics`, head_sha: env.GITHUB_SHA, status: 'completed', conclusion: success ? 'success' : 'failure', output: { title: `${kind} validation results (actual execution)`, summary: Buffer.from(summary).subarray(0, 62000).toString('utf8'), text: Buffer.from(text).subarray(0, 62000).toString('utf8') } }),
})
if (!response.ok) throw new Error(`Could not publish diagnostics check: ${response.status} ${await response.text()}`)
const result = await response.json()
console.log(`Published ${result.name}: ${result.conclusion}; check ${result.id}`)
