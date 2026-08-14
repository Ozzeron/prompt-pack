#!/usr/bin/env node
/**
 * Enforces meta/reuse-before-create: before a NEW source file appears, the agent has to
 * confront what already exists under that name.
 *
 * Fires only when all of these hold:
 *   - the Write target does not exist yet (an overwrite is an edit, not a creation)
 *   - it is a code file (docs, configs, and fixtures churn too much to gate)
 *   - the repo already contains a file with the same name, or the same name modulo
 *     case, separators, and extension
 *
 * The decision is "ask", never "deny": duplication is sometimes correct (a per-package
 * index.ts, a route handler per route). The point is that the justification happens
 * before the file exists, which is exactly what the skill asks for in prose.
 */
import { existsSync, readdirSync, statSync } from 'node:fs';
import { join, basename, extname, relative, isAbsolute } from 'node:path';
import { guard, decide, normalize } from './lib.mjs';

const CODE_EXT = new Set([
  '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.vue', '.svelte',
  '.py', '.rb', '.go', '.rs', '.java', '.kt', '.swift', '.php', '.cs',
  '.css', '.scss', '.sass', '.sql',
]);

const SKIP_DIR = new Set([
  'node_modules', '.git', 'dist', 'build', 'out', 'coverage', 'target',
  '.next', '.nuxt', '.turbo', '.svelte-kit', '.venv', 'venv', '__pycache__',
  'vendor', '.cache', '.pytest_cache', '.mypy_cache', 'tmp',
]);

const MAX_FILES = 20000;
const MAX_DEPTH = 12;

// "UserCard.tsx", "user-card.ts", and "user_card.jsx" all collapse to "usercard": the
// interesting collision is the concept, not the spelling.
const stem = (name) => basename(name, extname(name)).toLowerCase().replace(/[^a-z0-9]/g, '');

// Index-style files are legitimately repeated once per module — gating them would train
// the user to click through the prompt, which is worse than not asking.
const GENERIC = new Set(['index', 'types', 'utils', 'constants', 'helpers', 'main', 'mod', 'init']);

function walk(root) {
  const found = [];
  let budget = MAX_FILES;
  const stack = [{ dir: root, depth: 0 }];
  while (stack.length > 0 && budget > 0) {
    const { dir, depth } = stack.pop();
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      if (budget <= 0) break;
      if (entry.name.startsWith('.') && entry.isDirectory() && !SKIP_DIR.has(entry.name)) {
        // Hidden dirs other than the known-noise ones are rarely source; skip them too.
        continue;
      }
      if (entry.isDirectory()) {
        if (SKIP_DIR.has(entry.name) || depth >= MAX_DEPTH) continue;
        stack.push({ dir: join(dir, entry.name), depth: depth + 1 });
        continue;
      }
      budget -= 1;
      if (CODE_EXT.has(extname(entry.name).toLowerCase())) {
        found.push(join(dir, entry.name));
      }
    }
  }
  return found;
}

guard((payload) => {
  const target = (payload.tool_input || {}).file_path;
  if (!target) return;
  if (existsSync(target)) return; // editing an existing file
  if (!CODE_EXT.has(extname(target).toLowerCase())) return;

  const targetStem = stem(target);
  if (!targetStem || GENERIC.has(targetStem)) return;

  const root = payload.cwd && existsSync(payload.cwd) ? payload.cwd : process.cwd();
  const candidates = walk(root).filter((f) => stem(f) === targetStem);
  if (candidates.length === 0) return;

  const shown = candidates
    .slice(0, 5)
    .map((f) => normalize(isAbsolute(f) ? relative(root, f) : f))
    .join(', ');
  const more = candidates.length > 5 ? ` (+${candidates.length - 5} more)` : '';

  decide(
    'ask',
    `reuse-before-create: ${normalize(basename(target))} does not exist yet, but the repo already ` +
      `has ${candidates.length} file(s) covering the same name: ${shown}${more}. Open at least one ` +
      'and state in one line why reuse, extension, or composition does not work before creating a new file.',
  );
});
