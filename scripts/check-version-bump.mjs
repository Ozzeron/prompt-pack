#!/usr/bin/env node
/**
 * Version-bump gate.
 *
 * For every prompts/<category>/<name>/SKILL.md whose CONTENT changed versus the
 * merge-base with the target branch, require that the frontmatter `metadata.pp-version`
 * field also changed. This keeps the CHANGELOG / release history honest: a
 * skill edit that ships without a version bump is invisible to anyone tracking
 * versions.
 *
 *   - Brand-new skills pass automatically (nothing to bump against).
 *   - Deleted skills pass (nothing to keep in sync).
 *   - Pure renames with identical content pass (no content change).
 *   - A content change with an unchanged (or missing) version fails.
 *
 * Base ref: env BASE_REF (default origin/main). Requires full history on the
 * checkout (fetch-depth: 0) so the merge-base is reachable.
 *
 * Exit code: 0 if clean, 1 on any violation (or if the base ref can't resolve).
 */

import { execFileSync } from 'node:child_process';
import { readFileSync, existsSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import YAML from 'yaml';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const BASE_REF = process.env.BASE_REF || 'origin/main';

function git(args) {
  return execFileSync('git', args, { cwd: REPO_ROOT, encoding: 'utf8' });
}

function tryGit(args) {
  try {
    return git(args);
  } catch {
    return null;
  }
}

// Resolve the merge-base of BASE_REF and HEAD; fall back to BASE_REF resolved
// directly as a commit if a merge-base can't be computed.
function resolveBase() {
  const mb = tryGit(['merge-base', BASE_REF, 'HEAD']);
  if (mb && mb.trim()) return mb.trim();
  const rev = tryGit(['rev-parse', BASE_REF]);
  if (rev && rev.trim()) return rev.trim();
  return null;
}

function parseVersion(content) {
  if (content == null) return null;
  const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/);
  if (!m) return null;
  try {
    const data = YAML.parse(m[1]);
    if (data && typeof data === 'object') {
      // Current shape: metadata.pp-version. Pre-0.5 shape: a top-level `version` key.
      // The fallback matters for the gate itself — the base ref of any PR opened around
      // the migration still carries the old shape, and reading null there would report a
      // spurious "no base version" instead of comparing the two.
      const meta = data.metadata;
      const fromMeta =
        meta && typeof meta === 'object' && !Array.isArray(meta) ? meta['pp-version'] : undefined;
      const version = fromMeta !== undefined && fromMeta !== null ? fromMeta : data.version;
      if (version !== undefined && version !== null) return String(version);
    }
  } catch {
    /* malformed frontmatter — treat as no version */
  }
  return null;
}

// File content at a git ref, or null if the path does not exist there.
function showAtRef(ref, path) {
  return tryGit(['show', `${ref}:${path}`]);
}

// Current working-tree content, or null if the file is gone. Reading the
// working tree (not HEAD) means the gate catches both committed PR diffs and
// uncommitted local edits, so it is testable without a commit.
function readWorktree(path) {
  const abs = join(REPO_ROOT, path);
  return existsSync(abs) ? readFileSync(abs, 'utf8') : null;
}

function isSkill(path) {
  return /^prompts\/.+\/SKILL\.md$/.test(path);
}

function main() {
  const base = resolveBase();
  if (!base) {
    console.error(`check-version-bump: could not resolve a base ref (BASE_REF=${BASE_REF}).`);
    console.error('Ensure the base branch is fetched (check out with fetch-depth: 0).');
    process.exit(1);
  }
  console.log(`Version-bump gate: comparing working tree against merge-base ${base.slice(0, 12)} (BASE_REF=${BASE_REF})\n`);

  // Diff the base against the working tree so both committed and local changes
  // are covered. -M detects renames (reported as R<score>\told\tnew).
  const raw = git(['diff', '--name-status', '-M', base, '--', 'prompts']);
  const lines = raw.split(/\r?\n/).filter(Boolean);

  const report = [];
  const violations = [];
  let verified = 0;

  for (const line of lines) {
    const parts = line.split('\t');
    const status = parts[0];
    const code = status[0];

    let oldPath;
    let newPath;
    if (code === 'R' || code === 'C') {
      oldPath = parts[1];
      newPath = parts[2];
    } else {
      oldPath = parts[1];
      newPath = parts[1];
    }

    if (!isSkill(newPath) && !isSkill(oldPath)) continue;

    if (code === 'A') {
      report.push(`  NEW   ${newPath} — new skill, no bump required`);
      continue;
    }
    if (code === 'D') {
      report.push(`  DEL   ${oldPath} — deleted, no bump required`);
      continue;
    }

    const baseContent = showAtRef(base, oldPath);
    const curContent = readWorktree(newPath);

    if (curContent === null) {
      report.push(`  DEL   ${oldPath} — gone from working tree, no bump required`);
      continue;
    }
    // Rename (or copy) that didn't actually change bytes — nothing to bump.
    if (baseContent !== null && baseContent === curContent) {
      report.push(`  MOVE  ${newPath} — rename only, content identical`);
      continue;
    }
    // No base version to compare against — treat as brand-new content.
    if (baseContent === null) {
      report.push(`  NEW   ${newPath} — no base version, treated as new`);
      continue;
    }

    verified += 1;
    const baseVer = parseVersion(baseContent);
    const curVer = parseVersion(curContent);

    if (curVer === null) {
      violations.push(`${newPath}: content changed but frontmatter has no 'metadata.pp-version' field`);
      continue;
    }
    if (baseVer !== null && baseVer === curVer) {
      violations.push(`${newPath}: content changed but version not bumped (still ${curVer})`);
      continue;
    }
    report.push(`  BUMP  ${newPath} — version ${baseVer ?? '(none)'} -> ${curVer}`);
  }

  for (const r of report) console.log(r);
  if (report.length === 0 && violations.length === 0) console.log('  (no SKILL.md changes vs base)');
  console.log();

  if (violations.length > 0) {
    console.error('Version-bump gate FAILED:');
    for (const v of violations) console.error(`  - ${v}`);
    console.error("\nEvery SKILL.md whose content changed must also bump its frontmatter 'metadata.pp-version'.");
    process.exit(1);
  }

  console.log(`Version-bump gate passed (${verified} changed skill(s) verified).`);
  process.exit(0);
}

main();
