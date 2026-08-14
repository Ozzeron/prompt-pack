#!/usr/bin/env node
/**
 * Behaviour test for the enforcement hooks.
 *
 * Each case feeds a real PreToolUse payload to a real hook process and asserts the
 * decision, so the pack cannot claim enforcement it does not have. Also asserts the
 * fail-open contract: garbage in, no decision out, exit 0.
 *
 * Exit code: 0 if every case passes, 1 otherwise.
 */

import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HOOKS = resolve(__dirname, '..', 'hooks', 'scripts');

// A throwaway repo so guard-new-file has something real to search.
const repo = mkdtempSync(join(tmpdir(), 'pp-hooks-'));
mkdirSync(join(repo, 'src', 'components'), { recursive: true });
mkdirSync(join(repo, 'src', 'ui'), { recursive: true });
writeFileSync(join(repo, 'src', 'components', 'UserCard.tsx'), 'export const UserCard = () => null\n');
writeFileSync(join(repo, 'src', 'ui', 'index.ts'), 'export {}\n');

function run(script, payload) {
  const res = spawnSync(process.execPath, [join(HOOKS, script)], {
    input: typeof payload === 'string' ? payload : JSON.stringify(payload),
    encoding: 'utf8',
  });
  let decision = null;
  let reason = '';
  const out = (res.stdout || '').trim();
  if (out) {
    try {
      const parsed = JSON.parse(out);
      decision = parsed.hookSpecificOutput?.permissionDecision ?? null;
      reason = parsed.hookSpecificOutput?.permissionDecisionReason ?? '';
    } catch {
      decision = '<unparseable stdout>';
      reason = out;
    }
  }
  return { status: res.status, decision, reason, stderr: (res.stderr || '').trim() };
}

const pre = (tool, input, extra = {}) => ({
  hook_event_name: 'PreToolUse',
  session_id: 'test',
  cwd: repo,
  permission_mode: 'default',
  tool_name: tool,
  tool_input: input,
  ...extra,
});

const cases = [
  // --- guard-noise-reads ------------------------------------------------------------
  ['noise: node_modules read is denied', 'guard-noise-reads.mjs',
    pre('Read', { file_path: `${repo}/node_modules/react/index.js` }), 'deny'],
  ['noise: lockfile read is denied', 'guard-noise-reads.mjs',
    pre('Read', { file_path: `${repo}/pnpm-lock.yaml` }), 'deny'],
  ['noise: minified bundle is denied', 'guard-noise-reads.mjs',
    pre('Read', { file_path: `${repo}/public/app.min.js` }), 'deny'],
  ['noise: git internals are denied', 'guard-noise-reads.mjs',
    pre('Grep', { pattern: 'x', path: `${repo}/.git/objects/ab` }), 'deny'],
  ['noise: build output asks instead of blocking', 'guard-noise-reads.mjs',
    pre('Read', { file_path: `${repo}/dist/bundle.js` }), 'ask'],
  ['noise: .next output asks', 'guard-noise-reads.mjs',
    pre('Read', { file_path: `${repo}/.next/server/page.js` }), 'ask'],
  ['noise: ordinary source passes through', 'guard-noise-reads.mjs',
    pre('Read', { file_path: `${repo}/src/components/UserCard.tsx` }), null],
  ['noise: a path merely containing "dist" passes through', 'guard-noise-reads.mjs',
    pre('Read', { file_path: `${repo}/src/distance.ts` }), null],

  // --- guard-new-file --------------------------------------------------------------
  ['new file: same-name collision asks', 'guard-new-file.mjs',
    pre('Write', { file_path: `${repo}/src/ui/UserCard.tsx`, content: 'x' }), 'ask'],
  ['new file: collision modulo case and separators asks', 'guard-new-file.mjs',
    pre('Write', { file_path: `${repo}/src/ui/user-card.ts`, content: 'x' }), 'ask'],
  ['new file: genuinely new name passes through', 'guard-new-file.mjs',
    pre('Write', { file_path: `${repo}/src/ui/InvoiceTotals.tsx`, content: 'x' }), null],
  ['new file: overwriting an existing file is an edit, not a creation', 'guard-new-file.mjs',
    pre('Write', { file_path: `${repo}/src/components/UserCard.tsx`, content: 'x' }), null],
  ['new file: generic index.ts is not gated', 'guard-new-file.mjs',
    pre('Write', { file_path: `${repo}/src/components/index.ts`, content: 'x' }), null],
  ['new file: markdown is not gated', 'guard-new-file.mjs',
    pre('Write', { file_path: `${repo}/docs/UserCard.md`, content: 'x' }), null],

  // --- guard-new-dependency -------------------------------------------------------
  ['dependency: npm install <pkg> asks', 'guard-new-dependency.mjs',
    pre('Bash', { command: 'npm install lodash.debounce' }), 'ask'],
  ['dependency: pnpm add -D asks', 'guard-new-dependency.mjs',
    pre('Bash', { command: 'pnpm add -D vitest' }), 'ask'],
  ['dependency: cargo add asks', 'guard-new-dependency.mjs',
    pre('Bash', { command: 'cargo add serde --features derive' }), 'ask'],
  ['dependency: bare npm install (restore) passes through', 'guard-new-dependency.mjs',
    pre('Bash', { command: 'npm install' }), null],
  ['dependency: npm ci passes through', 'guard-new-dependency.mjs',
    pre('Bash', { command: 'npm ci' }), null],
  ['dependency: pnpm install --frozen-lockfile passes through', 'guard-new-dependency.mjs',
    pre('Bash', { command: 'pnpm install --frozen-lockfile' }), null],
  ['dependency: unrelated command passes through', 'guard-new-dependency.mjs',
    pre('Bash', { command: 'npm run lint' }), null],

  // --- fail-open contract ---------------------------------------------------------
  ['fail-open: malformed stdin yields no decision', 'guard-noise-reads.mjs', 'not json at all', null],
  ['fail-open: empty stdin yields no decision', 'guard-new-file.mjs', '', null],
  ['fail-open: payload without tool_input yields no decision', 'guard-new-dependency.mjs',
    { hook_event_name: 'PreToolUse', tool_name: 'Bash' }, null],
];

let failures = 0;
console.log(`Testing enforcement hooks (${cases.length} cases)\n`);
for (const [label, script, payload, expected] of cases) {
  const { status, decision, stderr } = run(script, payload);
  const ok = decision === expected && status === 0;
  if (ok) {
    console.log(`  PASS  ${label}`);
  } else {
    failures += 1;
    console.log(`  FAIL  ${label}`);
    console.log(`        expected decision ${JSON.stringify(expected)}, got ${JSON.stringify(decision)} (exit ${status})`);
    if (stderr) console.log(`        stderr: ${stderr}`);
  }
}

rmSync(repo, { recursive: true, force: true });

console.log();
if (failures > 0) {
  console.log(`${failures} hook case(s) failed.`);
  process.exit(1);
}
console.log('All hook cases pass.');
process.exit(0);
