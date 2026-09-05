#!/usr/bin/env node
/**
 * Lint every prompts/<category>/<name>/SKILL.md against the format contract.
 *
 * Checks:
 * - YAML frontmatter present with required fields (name, description)
 * - Only Agent Skills spec keys at the top level (name, description, license,
 *   compatibility, metadata, allowed-tools); everything pack-specific lives under
 *   metadata as pp-* string values
 * - metadata carries pp-category (matching the directory), pp-version (semver),
 *   pp-activation (native | inherit-only | legacy)
 * - description length within 120–500 chars, contains an explicit "Use when" clause
 *   and a negative trigger ("Not for" / "Don't use"), because the description is the
 *   only activation surface on native hosts
 * - name matches directory name (kebab-case)
 * - SKILL.md length within 80–240 lines (core budget); conditional material lives in
 *   references/ and is linked with an explicit load condition
 * - For non-meta skills: required sections present in order
 *   (When to use → Scope → Inherits → Token discipline → Process → Output format → Anti-patterns)
 * - All internal markdown links to ../...SKILL.md resolve
 * - Every inline `<category>/<name>` skill reference in any skill body resolves to an
 *   existing skill (refs whose category is not a real prompts/ dir are ignored)
 * - No project-specific leakage (private terms are stored as SHA-256 hashes in
 *   scripts/leakage-hashes.json; see scripts/leakage-hash.mjs to add one)
 * - All profiles in install.ps1 / install.sh reference existing skills
 * - All references in task-router active table point to existing skills
 * - No two skill descriptions are near-duplicates (Jaccard token similarity below threshold)
 *
 * Exit code: 0 if clean, 1 if any failures.
 */

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import YAML from 'yaml';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const PROMPTS_ROOT = join(REPO_ROOT, 'prompts');

const REQUIRED_FRONTMATTER = ['name', 'description'];
// The Agent Skills spec fixes the top-level frontmatter keys. Anything pack-specific
// belongs under `metadata` (a map of string keys to string values), prefixed pp- so it
// cannot collide with another publisher's metadata. A skill that invents top-level keys
// still loads in Claude Code today, but fails `skills-ref validate` and is not portable.
const ALLOWED_TOP_LEVEL = new Set([
  'name',
  'description',
  'license',
  'compatibility',
  'metadata',
  'allowed-tools',
]);
const REQUIRED_METADATA = ['pp-category', 'pp-version', 'pp-activation'];
// native      - discovered by the host from `description` alone
// inherit-only - loaded by reference from another skill's Inherits section, never self-activates
// legacy      - kept for pre-Agent-Skills flows (orchestrator routing); excluded from native targets
const ACTIVATION_VALUES = new Set(['native', 'inherit-only', 'legacy']);
// Required sections that must appear in this exact relative order in non-meta skills.
// Process is intentionally not required — some skills (handoff, postgres-supabase,
// database-migrations) replace a single Process section with multiple topic-specific
// guidance sections; the Output format still defines the structured deliverable.
const REQUIRED_SECTIONS_NON_META = [
  '## When to use',
  '## Scope',
  '## Inherits',
  '## Token discipline (specific)',
  '## Output format',
  '## Anti-patterns',
];
const REQUIRED_SECTIONS_META_MIN = ['## When to use', '## Anti-patterns'];

// The description is the whole activation surface on native hosts: it is the only part
// of a skill loaded before the host decides to open it. The spec ceiling is 1024 chars;
// 500 is the pack's own budget (23 skills x ~400 chars stays inside the ~2% context cap
// hosts allocate to the skill index). The floor exists because a 100-char description
// cannot carry what the skill does AND when to use it AND when not to.
const DESCRIPTION_MAX = 500;
const DESCRIPTION_MIN = 120;
// Required description clauses. "Use when" is the trigger surface; a negative clause is
// what stops sibling skills from stealing each other's activations (code-review vs the
// *-audit skills, doc-writer vs ai-agent-docs).
const DESCRIPTION_USE_WHEN = /\buse when\b/i;
const DESCRIPTION_NEGATIVE = /\b(not for|don't use|do not use)\b/i;
// ASCII-only: install.ps1 re-emits this exact line under Windows PowerShell 5.1, whose
// default file APIs double-encode non-ASCII (the reason templates/cursor-bridge.mdc is
// copied byte-for-byte instead of generated). Multilingual routing belongs in that
// template and the AGENTS.md bridge, not in a field the installers rewrite.
const NON_ASCII = /[^\x20-\x7E]/;
const LENGTH_MIN = 80;
// Core budget. The spec ceiling is 500 lines / 5000 tokens for the whole SKILL.md, but
// everything in this file loads on every activation, so the pack keeps the always-loaded
// core well under it and pushes conditional material (templates, per-branch checklists,
// worked examples) into references/ behind an explicit load condition.
const LENGTH_MAX = 240;
// A reference file the agent must read in full to use is no better than inline text.
const REFERENCE_MAX = 250;
// The pointer line for a reference file has to say WHEN to load it — "see references/ for
// details" defeats progressive disclosure because the agent cannot tell whether this run
// needs it.
const LOAD_CONDITION = /\b(when|if|before|unless)\b/i;

// Description-collision threshold: max allowed Jaccard similarity between the tokenized
// descriptions of any two skills. Descriptions are the primary activation surface for
// native skill matchers (Cursor/Codex/Claude Code), so two near-identical descriptions
// blur routing between them. Calibration: the current 23 skills peak at 0.23 pairwise
// similarity (architecture/frontend-feature <-> interface/ui-designer). 0.50 leaves
// >2x headroom over that while still catching genuine near-duplicates — two skills that
// share half their meaningful description tokens is a real collision, not coincidence.
const DESCRIPTION_SIMILARITY_MAX = 0.5;
// Tiny stopword list dropped before comparison so shared connective words don't inflate
// similarity. Tokens shorter than 3 chars are also dropped (see tokenizeDescription).
const DESCRIPTION_STOPWORDS = new Set(['the', 'and', 'for', 'with', 'use', 'when', 'your']);

// Skills that create or modify production code (as opposed to reviewing, planning,
// or summarising). Each must inherit meta/reuse-before-create so the DRY decision
// flow is in scope before any new artifact is added. CONTRIBUTING.md reviewer
// checklist references this same invariant.
const CODE_CREATING_SKILLS = new Set([
  'infra/docker',
  'architecture/backend-api',
  'architecture/frontend-feature',
  'architecture/database-schema',
  'architecture/database-migrations',
  'architecture/postgres-supabase',
  'architecture/refactor-planner',
  'interface/ui-designer',
  'delivery/test-writer',
  'delivery/doc-writer',
  'delivery/ai-agent-docs',
]);

// Plain-text leakage terms are limited to what is public anyway (the repo
// owner's handle). Everything private — project codenames, employer names,
// personal @handles that previously slipped into example ADR deciders — lives
// as SHA-256 hashes in scripts/leakage-hashes.json so the blocklist itself
// does not republish the very terms it exists to keep out of the pack.
// Canonical placeholder names (alice, bob) are the safe substitutes in skills.
const LEAKAGE_TERMS = [
  /\bozzeron\b/i,
];

// Hashed private-term blocklist. Each entry is sha256(normalize(term)) where
// normalize() lowercases and strips every char outside [a-z0-9@]. Use
// `node scripts/leakage-hash.mjs "<term>"` to generate an entry.
const LEAKAGE_HASHES_PATH = join(__dirname, 'leakage-hashes.json');

function loadLeakageHashes() {
  if (!existsSync(LEAKAGE_HASHES_PATH)) return new Set();
  const parsed = JSON.parse(readFileSync(LEAKAGE_HASHES_PATH, 'utf8'));
  return new Set(parsed.hashes || []);
}

function normalizeLeakageTerm(term) {
  return term.toLowerCase().replace(/[^a-z0-9@]/g, '');
}

// Scan content for tokens (and adjacent token pairs, to catch hyphenated or
// spaced spellings like "some-name" / "some name") whose normalized hash is
// on the private blocklist.
function checkHashedLeakage(content, hashes) {
  if (hashes.size === 0) return [];
  const hits = [];
  const lower = content.toLowerCase();
  const tokenRe = /@?[a-z0-9]+/g;
  const tokens = [];
  let m;
  while ((m = tokenRe.exec(lower)) !== null) {
    tokens.push({ text: m[0], start: m.index, end: m.index + m[0].length });
  }
  const seen = new Set();
  const tryCandidate = (text, raw) => {
    const hash = createHash('sha256').update(normalizeLeakageTerm(text)).digest('hex');
    if (hashes.has(hash) && !seen.has(raw)) {
      seen.add(raw);
      hits.push(raw);
    }
  };
  for (let i = 0; i < tokens.length; i++) {
    tryCandidate(tokens[i].text, tokens[i].text);
    // Adjacent pair joined across a short separator (hyphen, space, underscore).
    if (i + 1 < tokens.length && tokens[i + 1].start - tokens[i].end <= 3) {
      const raw = lower.slice(tokens[i].start, tokens[i + 1].end);
      tryCandidate(tokens[i].text + tokens[i + 1].text, raw);
    }
  }
  return hits;
}

function findSkillFiles() {
  const skills = [];
  for (const category of readdirSync(PROMPTS_ROOT)) {
    const categoryPath = join(PROMPTS_ROOT, category);
    if (!statSync(categoryPath).isDirectory()) continue;
    for (const name of readdirSync(categoryPath)) {
      const skillDir = join(categoryPath, name);
      if (!statSync(skillDir).isDirectory()) continue;
      const skillFile = join(skillDir, 'SKILL.md');
      if (existsSync(skillFile)) {
        skills.push({ category, name, path: skillFile });
      }
    }
  }
  return skills;
}

/**
 * Parse YAML frontmatter using a real YAML parser. Returns:
 *   { ok: true, data: <parsed-object> }   on success
 *   { ok: false, error: <string> }        on parse failure or missing frontmatter
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/);
  if (!match) return { ok: false, error: 'missing or malformed YAML frontmatter (no --- delimiters)' };

  try {
    const data = YAML.parse(match[1]);
    if (data === null || typeof data !== 'object') {
      return { ok: false, error: 'frontmatter parsed to non-object' };
    }
    return { ok: true, data };
  } catch (e) {
    // Strip the noisy code-frame YAML adds; keep the headline.
    const msg = (e.message || String(e)).split('\n')[0];
    return { ok: false, error: `YAML parse error: ${msg}` };
  }
}

function extractSectionHeadings(body) {
  return body
    .split(/\r?\n/)
    .filter((line) => /^## /.test(line))
    .map((line) => line.trim());
}

// Returns the text content of the `## Inherits` section (lines between that heading
// and the next `## ` heading, or end of body). Returns '' if no Inherits section.
function extractInheritsBlock(body) {
  const lines = body.split(/\r?\n/);
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/^## Inherits\b/.test(lines[i])) {
      start = i + 1;
      break;
    }
  }
  if (start === -1) return '';
  let end = lines.length;
  for (let i = start; i < lines.length; i++) {
    if (/^## /.test(lines[i])) {
      end = i;
      break;
    }
  }
  return lines.slice(start, end).join('\n');
}

function isInOrder(found, required) {
  // Each required heading must appear in the document in the listed order.
  // Other headings between them are fine.
  let cursor = 0;
  for (const heading of found) {
    if (cursor >= required.length) break;
    // Match if any required heading still pending appears here. Order matters
    // only relative to other required headings, not arbitrary content headings.
    if (heading === required[cursor] || heading.startsWith(required[cursor] + ' ')) {
      cursor += 1;
    }
  }
  return cursor === required.length;
}

function checkLinks(body, fromPath) {
  const failures = [];
  const linkPattern = /\]\((\.\.[^)]*SKILL\.md|references\/[^)]+\.md)\)/g;
  let m;
  while ((m = linkPattern.exec(body)) !== null) {
    const target = resolve(dirname(fromPath), m[1]);
    if (!existsSync(target)) {
      failures.push(`broken link to ${m[1]}`);
    }
  }
  return failures;
}

/**
 * Progressive disclosure contract for a skill directory:
 *   - the only .md at the skill root is SKILL.md (everything else lives in references/)
 *   - every file in references/ is linked from SKILL.md
 *   - the linking line states a load condition, not just "see references/"
 *   - no reference file is so long that loading it is as costly as inlining it
 */
function checkReferences(skill, body) {
  const failures = [];
  const skillDir = dirname(skill.path);

  for (const entry of readdirSync(skillDir)) {
    if (entry === 'SKILL.md' || entry === 'CHANGELOG.md') continue;
    if (entry.endsWith('.md')) {
      failures.push(`${entry} sits at the skill root — move it to references/${entry}`);
    }
  }

  const refDir = join(skillDir, 'references');
  if (!existsSync(refDir)) return failures;

  const bodyLines = body.split(/\r?\n/);
  for (const file of readdirSync(refDir)) {
    if (!file.endsWith('.md')) continue;
    const linkLines = bodyLines.filter((l) => l.includes(`references/${file})`));
    if (linkLines.length === 0) {
      failures.push(`references/${file} is never linked from SKILL.md (dead reference)`);
      continue;
    }
    if (!linkLines.some((l) => LOAD_CONDITION.test(l))) {
      failures.push(
        `references/${file} is linked without a load condition (say when to read it, e.g. "read X when …")`,
      );
    }
    const refPath = join(refDir, file);
    const refContent = readFileSync(refPath, 'utf8');
    const refLines = refContent.split(/\r?\n/).length;
    if (refLines > REFERENCE_MAX) {
      failures.push(`references/${file} is ${refLines} lines > ${REFERENCE_MAX} — split it by topic`);
    }
    // Links inside a reference file resolve from references/, one level deeper than
    // SKILL.md. Moving a section out of a skill silently breaks every ../.. link it
    // carried, which is exactly what happened to frontend-feature's layer rules.
    for (const f of checkLinks(refContent, refPath)) {
      failures.push(`references/${file}: ${f}`);
    }
  }
  return failures;
}

const LEAKAGE_HASHES = loadLeakageHashes();

function checkLeakage(content) {
  const hits = [];
  for (const re of LEAKAGE_TERMS) {
    const m = content.match(re);
    if (m) hits.push(m[0]);
  }
  hits.push(...checkHashedLeakage(content, LEAKAGE_HASHES));
  return hits;
}

// Every inline `<category>/<name>` code span in a skill body must resolve to an existing
// skill — a generalization of the task-router reference check to all skills. Only refs
// whose first segment is a real prompts/ category directory are validated, so unrelated
// slash-paths in backticks (`docs/ai-rules`, `.agents/skills`, `src/index`) are ignored.
function checkInlineSkillReferences(body, skill, skillSet, categorySet) {
  const failures = [];
  // task-router keeps its special handling: the "## Planned" section lists forward-looking
  // skills that intentionally do not exist yet, so it stays exempt. This exemption applies
  // only to task-router; every other skill body is scanned in full.
  let scanBody = body;
  if (skill.category === 'meta' && skill.name === 'task-router') {
    scanBody = body.split(/^##\s*Planned/m)[0] || body;
  }
  const refRe = /`([a-z-]+\/[a-z-]+)`/g;
  const seen = new Set();
  let match;
  while ((match = refRe.exec(scanBody)) !== null) {
    const ref = match[1];
    if (seen.has(ref)) continue;
    seen.add(ref);
    const category = ref.split('/')[0];
    if (!categorySet.has(category)) continue; // not a skill reference — ignore
    if (!skillSet.has(ref)) {
      failures.push(`references missing skill: ${ref}`);
    }
  }
  return failures;
}

function lintSkill(skill, skillSet, categorySet) {
  const content = readFileSync(skill.path, 'utf8');
  // Trailing newline excluded: a POSIX-correct file would otherwise count one line more
  // than it has, which is how a 240-line budget silently became 239.
  const lineCount = content.replace(/\r?\n$/, '').split(/\r?\n/).length;
  const failures = [];

  const result = parseFrontmatter(content);
  if (!result.ok) {
    failures.push(result.error);
    return failures;
  }
  const fm = result.data;

  for (const key of REQUIRED_FRONTMATTER) {
    if (fm[key] === undefined || fm[key] === null || fm[key] === '') {
      failures.push(`missing frontmatter field: ${key}`);
    }
  }

  if (fm.name && fm.name !== skill.name) {
    failures.push(`frontmatter name "${fm.name}" != directory name "${skill.name}"`);
  }

  // Spec conformance: no invented top-level keys.
  for (const key of Object.keys(fm)) {
    if (!ALLOWED_TOP_LEVEL.has(key)) {
      failures.push(`non-spec top-level frontmatter key "${key}" (move it under metadata as pp-${key})`);
    }
  }

  if (typeof fm.description === 'string') {
    const desc = fm.description;
    if (desc.length > DESCRIPTION_MAX) {
      failures.push(`description ${desc.length} > ${DESCRIPTION_MAX} chars`);
    }
    if (desc.length < DESCRIPTION_MIN) {
      failures.push(
        `description ${desc.length} < ${DESCRIPTION_MIN} chars — too thin to carry what + when + when-not`,
      );
    }
    if (!DESCRIPTION_USE_WHEN.test(desc)) {
      failures.push('description has no "Use when …" clause (the trigger surface on native hosts)');
    }
    if (!DESCRIPTION_NEGATIVE.test(desc)) {
      failures.push('description has no negative trigger ("Not for …" / "Don\'t use …")');
    }
    const nonAscii = desc.match(NON_ASCII);
    if (nonAscii) {
      failures.push(`description contains non-ASCII character ${JSON.stringify(nonAscii[0])} (install.ps1 rewrites this line under PS 5.1)`);
    }
  }

  // metadata: pack-specific fields, string values only (spec: map of string -> string).
  const meta = fm.metadata;
  if (meta === undefined || meta === null) {
    failures.push('missing frontmatter field: metadata (pp-category, pp-version, pp-activation)');
  } else if (typeof meta !== 'object' || Array.isArray(meta)) {
    failures.push(`metadata must be a mapping, got ${Array.isArray(meta) ? 'list' : typeof meta}`);
  } else {
    for (const key of REQUIRED_METADATA) {
      if (meta[key] === undefined || meta[key] === null || meta[key] === '') {
        failures.push(`missing metadata field: ${key}`);
      }
    }
    for (const [key, value] of Object.entries(meta)) {
      if (typeof value !== 'string') {
        failures.push(`metadata.${key} must be a string, got ${Array.isArray(value) ? 'list' : typeof value}`);
      }
      if (!key.startsWith('pp-')) {
        failures.push(`metadata key "${key}" must be pp-prefixed to avoid cross-publisher collisions`);
      }
    }
    if (meta['pp-category'] && meta['pp-category'] !== skill.category) {
      failures.push(
        `metadata.pp-category "${meta['pp-category']}" != directory category "${skill.category}"`,
      );
    }
    if (typeof meta['pp-version'] === 'string' && !/^\d+\.\d+\.\d+$/.test(meta['pp-version'])) {
      failures.push(`metadata.pp-version "${meta['pp-version']}" is not semver`);
    }
    if (meta['pp-activation'] && !ACTIVATION_VALUES.has(meta['pp-activation'])) {
      failures.push(
        `metadata.pp-activation "${meta['pp-activation']}" not one of ${[...ACTIVATION_VALUES].join(' | ')}`,
      );
    }
    // inherit-only invariant, restated for the description era: a skill that is only ever
    // pulled in by another skill's Inherits section must say so in its description, or a
    // native host will match it directly and load foundation rules as if they were a task.
    if (meta['pp-activation'] === 'inherit-only' && typeof fm.description === 'string') {
      if (!/inherit/i.test(fm.description)) {
        failures.push(
          'pp-activation: inherit-only but the description does not say it is inherited rather than invoked',
        );
      }
    }
  }

  if (lineCount < LENGTH_MIN) failures.push(`length ${lineCount} < ${LENGTH_MIN} lines`);
  if (lineCount > LENGTH_MAX) failures.push(`length ${lineCount} > ${LENGTH_MAX} lines`);

  const body = content.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '');
  const headings = extractSectionHeadings(body);

  const required =
    skill.category === 'meta' ? REQUIRED_SECTIONS_META_MIN : REQUIRED_SECTIONS_NON_META;

  if (!isInOrder(headings, required)) {
    const found = headings.filter((h) => required.some((r) => h === r || h.startsWith(r + ' '))).join(' | ') || '(none of the required headings found)';
    failures.push(`required sections not in order. Expected order: ${required.join(' → ')}. Found: ${found}`);
  }

  failures.push(...checkLinks(body, skill.path));
  failures.push(...checkReferences(skill, body));
  failures.push(...checkInlineSkillReferences(body, skill, skillSet, categorySet));

  // Code-creating skills must inherit meta/reuse-before-create. The DRY decision flow
  // is the central anti-tech-debt mechanism; skipping it in any coding skill leaves a
  // hole the reviewer checklist explicitly forbids.
  const skillId = `${skill.category}/${skill.name}`;
  if (CODE_CREATING_SKILLS.has(skillId)) {
    const inheritsBlock = extractInheritsBlock(body);
    if (!/meta\/reuse-before-create/.test(inheritsBlock)) {
      failures.push(
        'code-creating skill must inherit meta/reuse-before-create (declared in ## Inherits)',
      );
    }
  }

  const leakage = checkLeakage(content);
  if (leakage.length > 0) {
    failures.push(`project-specific leakage: ${[...new Set(leakage)].join(', ')}`);
  }

  return failures;
}

function checkInstallerProfiles(skillIds) {
  const failures = [];
  const skillSet = new Set(skillIds);

  // install.ps1 — extract profile -> skill list mapping
  const ps1Path = join(REPO_ROOT, 'install.ps1');
  if (existsSync(ps1Path)) {
    const content = readFileSync(ps1Path, 'utf8');
    // Match `'<profile>' = @(` then capture every quoted skill path until `)`
    const blockRe = /'([a-z]+)'\s*=\s*@\(([\s\S]*?)\)/g;
    let match;
    while ((match = blockRe.exec(content)) !== null) {
      const profile = match[1];
      if (profile === 'all') continue; // built at runtime
      const skillRe = /'([a-z-]+\/[a-z-]+)'/g;
      let m2;
      while ((m2 = skillRe.exec(match[2])) !== null) {
        if (!skillSet.has(m2[1])) {
          failures.push(`install.ps1 profile "${profile}" references missing skill: ${m2[1]}`);
        }
      }
    }
  }

  // install.sh — heredoc style
  const shPath = join(REPO_ROOT, 'install.sh');
  if (existsSync(shPath)) {
    const content = readFileSync(shPath, 'utf8');
    // Match `<profile>)\n      cat <<EOF\n...\nEOF`
    const blockRe = /^\s*([a-z]+)\)\s*\n\s*cat <<EOF\s*\n([\s\S]*?)\nEOF/gm;
    let match;
    while ((match = blockRe.exec(content)) !== null) {
      const profile = match[1];
      if (profile === 'all') continue;
      for (const line of match[2].split(/\r?\n/)) {
        const skill = line.trim();
        if (!skill) continue;
        // Profile blocks contain bare skill paths. Anything else is noise.
        if (!/^[a-z-]+\/[a-z-]+$/.test(skill)) continue;
        if (!skillSet.has(skill)) {
          failures.push(`install.sh profile "${profile}" references missing skill: ${skill}`);
        }
      }
    }
  }

  return failures;
}

function extractPs1Profiles() {
  const ps1Path = join(REPO_ROOT, 'install.ps1');
  if (!existsSync(ps1Path)) return {};
  const content = readFileSync(ps1Path, 'utf8');
  const profiles = {};
  const blockRe = /'([a-z]+)'\s*=\s*@\(([\s\S]*?)\)/g;
  let match;
  while ((match = blockRe.exec(content)) !== null) {
    const profile = match[1];
    if (profile === 'all') continue;
    const skillRe = /'([a-z-]+\/[a-z-]+)'/g;
    const skills = [];
    let m2;
    while ((m2 = skillRe.exec(match[2])) !== null) skills.push(m2[1]);
    profiles[profile] = skills;
  }
  return profiles;
}

function extractShProfiles() {
  const shPath = join(REPO_ROOT, 'install.sh');
  if (!existsSync(shPath)) return {};
  const content = readFileSync(shPath, 'utf8');
  const profiles = {};
  const blockRe = /^\s*([a-z]+)\)\s*\n\s*cat <<EOF\s*\n([\s\S]*?)\nEOF/gm;
  let match;
  while ((match = blockRe.exec(content)) !== null) {
    const profile = match[1];
    if (profile === 'all') continue;
    const skills = [];
    for (const line of match[2].split(/\r?\n/)) {
      const trimmed = line.trim();
      if (/^[a-z-]+\/[a-z-]+$/.test(trimmed)) skills.push(trimmed);
    }
    profiles[profile] = skills;
  }
  return profiles;
}

function checkProfileParity() {
  const failures = [];
  const psProfiles = extractPs1Profiles();
  const shProfiles = extractShProfiles();

  const allProfiles = new Set([...Object.keys(psProfiles), ...Object.keys(shProfiles)]);
  for (const profile of allProfiles) {
    const ps = psProfiles[profile];
    const sh = shProfiles[profile];
    if (!ps) {
      failures.push(`profile "${profile}" exists in install.sh but not install.ps1`);
      continue;
    }
    if (!sh) {
      failures.push(`profile "${profile}" exists in install.ps1 but not install.sh`);
      continue;
    }
    const psSet = new Set(ps);
    const shSet = new Set(sh);
    const psOnly = [...psSet].filter((s) => !shSet.has(s));
    const shOnly = [...shSet].filter((s) => !psSet.has(s));
    if (psOnly.length > 0) {
      failures.push(`profile "${profile}": install.ps1 has skills not in install.sh: ${psOnly.join(', ')}`);
    }
    if (shOnly.length > 0) {
      failures.push(`profile "${profile}": install.sh has skills not in install.ps1: ${shOnly.join(', ')}`);
    }
  }
  return { failures, profiles: psProfiles, shProfiles };
}

function checkReadmeProfileCounts() {
  const failures = [];
  const readmePath = join(REPO_ROOT, 'README.md');
  if (!existsSync(readmePath)) return { failures: ['README.md missing'] };
  const content = readFileSync(readmePath, 'utf8');

  const psProfiles = extractPs1Profiles();
  // Look for table rows like `| \`minimal\`   | 4 | ...`
  const rowRe = /^\|\s*`([a-z]+)`\s*\|\s*(\d+)\s*\|/gm;
  let match;
  const seen = new Set();
  while ((match = rowRe.exec(content)) !== null) {
    const profile = match[1];
    const claimed = parseInt(match[2], 10);
    if (seen.has(profile)) continue;
    seen.add(profile);
    if (profile === 'all') {
      const skills = findSkillFiles();
      if (claimed !== skills.length) {
        failures.push(`README "all" profile claims ${claimed} skills, actual count is ${skills.length}`);
      }
      continue;
    }
    if (!psProfiles[profile]) continue;
    if (psProfiles[profile].length !== claimed) {
      failures.push(`README profile "${profile}" claims ${claimed} skills, install.ps1 lists ${psProfiles[profile].length}`);
    }
  }
  return { failures };
}

/**
 * The pack's security claim is that installing a skill profile installs Markdown and
 * nothing else — no scripts to audit, no post-install step, nothing that executes. That
 * claim is only worth making if it is enforced, so anything executable under prompts/ is a
 * lint failure. (The opt-in enforcement hooks DO ship code; they live in hooks/, are
 * documented in SECURITY.md, and are installed by a separate plugin.)
 */
const EXECUTABLE_EXT = new Set([
  '.sh', '.bash', '.zsh', '.ps1', '.psm1', '.bat', '.cmd', '.py', '.rb', '.pl',
  '.js', '.mjs', '.cjs', '.ts', '.exe', '.dll', '.so', '.dylib', '.jar', '.wasm',
]);

function checkNoExecutableCode() {
  const failures = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      const dot = entry.name.lastIndexOf('.');
      const ext = dot === -1 ? '' : entry.name.slice(dot).toLowerCase();
      if (EXECUTABLE_EXT.has(ext)) {
        failures.push(`executable file under prompts/: ${relative(REPO_ROOT, full)}`);
      }
    }
  };
  walk(PROMPTS_ROOT);
  return failures;
}

function checkRouterReferences(skillIds) {
  const failures = [];
  const skillSet = new Set(skillIds);

  const routerPath = join(REPO_ROOT, 'prompts/meta/task-router/SKILL.md');
  if (!existsSync(routerPath)) {
    return [`task-router skill missing: ${routerPath}`];
  }

  const content = readFileSync(routerPath, 'utf8');
  // The router has two sections: an active routing table and a Planned section.
  // Only the active table should reference real skills. Split at the Planned heading.
  const activeSection = content.split(/^##\s*Planned/m)[0] || '';

  // Match `\`<category>/<name>\`` patterns in the active section.
  const refRe = /`([a-z-]+\/[a-z-]+)`/g;
  const seen = new Set();
  let match;
  while ((match = refRe.exec(activeSection)) !== null) {
    const ref = match[1];
    if (seen.has(ref)) continue;
    seen.add(ref);
    if (!skillSet.has(ref)) {
      failures.push(`task-router active table references missing skill: ${ref}`);
    }
  }

  return failures;
}

// Lowercase, split on non-alphanumerics, drop stopwords and tokens shorter than 3 chars.
function tokenizeDescription(desc) {
  return new Set(
    String(desc)
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((w) => w.length >= 3 && !DESCRIPTION_STOPWORDS.has(w)),
  );
}

function jaccardSimilarity(a, b) {
  if (a.size === 0 && b.size === 0) return 0;
  let inter = 0;
  for (const t of a) if (b.has(t)) inter += 1;
  const union = a.size + b.size - inter;
  return union === 0 ? 0 : inter / union;
}

// Pairwise-compare every skill description; fail any pair at/above the similarity ceiling.
function checkDescriptionCollisions(skills) {
  const failures = [];
  const entries = [];
  for (const skill of skills) {
    const content = readFileSync(skill.path, 'utf8');
    const parsed = parseFrontmatter(content);
    if (!parsed.ok || typeof parsed.data.description !== 'string') continue;
    entries.push({
      id: `${skill.category}/${skill.name}`,
      tokens: tokenizeDescription(parsed.data.description),
    });
  }
  for (let i = 0; i < entries.length; i++) {
    for (let j = i + 1; j < entries.length; j++) {
      const sim = jaccardSimilarity(entries[i].tokens, entries[j].tokens);
      if (sim >= DESCRIPTION_SIMILARITY_MAX) {
        failures.push(
          `descriptions too similar (${sim.toFixed(2)} >= ${DESCRIPTION_SIMILARITY_MAX}): ${entries[i].id} <-> ${entries[j].id}`,
        );
      }
    }
  }
  return failures;
}

function main() {
  const skills = findSkillFiles();
  const skillIds = skills.map((s) => `${s.category}/${s.name}`);
  const skillSet = new Set(skillIds);
  const categorySet = new Set(skills.map((s) => s.category));
  let totalFailures = 0;

  console.log(`Linting ${skills.length} skills...\n`);

  for (const skill of skills.sort((a, b) =>
    `${a.category}/${a.name}`.localeCompare(`${b.category}/${b.name}`),
  )) {
    const failures = lintSkill(skill, skillSet, categorySet);
    const id = `${skill.category}/${skill.name}`;
    if (failures.length === 0) {
      console.log(`  PASS  ${id}`);
    } else {
      console.log(`  FAIL  ${id}`);
      for (const f of failures) console.log(`        - ${f}`);
      totalFailures += failures.length;
    }
  }

  // Cross-checks beyond per-skill linting.
  console.log();
  console.log('Cross-checks:');

  const installerFailures = checkInstallerProfiles(skillIds);
  if (installerFailures.length === 0) {
    console.log('  PASS  installer profiles reference existing skills');
  } else {
    console.log('  FAIL  installer profiles');
    for (const f of installerFailures) console.log(`        - ${f}`);
    totalFailures += installerFailures.length;
  }

  const parityResult = checkProfileParity();
  if (parityResult.failures.length === 0) {
    console.log('  PASS  install.sh and install.ps1 profiles match');
  } else {
    console.log('  FAIL  profile parity');
    for (const f of parityResult.failures) console.log(`        - ${f}`);
    totalFailures += parityResult.failures.length;
  }

  const readmeResult = checkReadmeProfileCounts();
  if (readmeResult.failures.length === 0) {
    console.log('  PASS  README profile counts match installer');
  } else {
    console.log('  FAIL  README profile counts');
    for (const f of readmeResult.failures) console.log(`        - ${f}`);
    totalFailures += readmeResult.failures.length;
  }

  const routerFailures = checkRouterReferences(skillIds);
  if (routerFailures.length === 0) {
    console.log('  PASS  task-router active table references existing skills');
  } else {
    console.log('  FAIL  task-router');
    for (const f of routerFailures) console.log(`        - ${f}`);
    totalFailures += routerFailures.length;
  }

  const executableFailures = checkNoExecutableCode();
  if (executableFailures.length === 0) {
    console.log('  PASS  no executable code under prompts/ (skills are Markdown only)');
  } else {
    console.log('  FAIL  executable code under prompts/');
    for (const f of executableFailures) console.log(`        - ${f}`);
    totalFailures += executableFailures.length;
  }

  const collisionFailures = checkDescriptionCollisions(skills);
  if (collisionFailures.length === 0) {
    console.log('  PASS  no near-duplicate skill descriptions');
  } else {
    console.log('  FAIL  description collisions');
    for (const f of collisionFailures) console.log(`        - ${f}`);
    totalFailures += collisionFailures.length;
  }

  console.log();
  if (totalFailures === 0) {
    console.log(`All ${skills.length} skills + cross-checks pass.`);
    process.exit(0);
  } else {
    console.log(`${totalFailures} failure(s) across ${skills.length} skills + cross-checks.`);
    process.exit(1);
  }
}

main();
