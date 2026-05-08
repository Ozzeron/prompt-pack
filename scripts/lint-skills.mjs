#!/usr/bin/env node
/**
 * Lint every prompts/<category>/<name>/SKILL.md against the format contract.
 *
 * Checks:
 * - YAML frontmatter present with required fields (name, description, category, version)
 * - description ≤ 120 chars
 * - name matches directory name (kebab-case)
 * - File length within 80–310 lines
 * - For non-meta skills: required sections present in order
 *   (When to use → Scope → Inherits → Token discipline → Process → Output format → Anti-patterns)
 * - All internal markdown links to ../...SKILL.md resolve
 * - No project-specific leakage (Ozzeron, project-a, project-b-fit, med-project-c, acme-data, etc.)
 * - All profiles in install.ps1 / install.sh reference existing skills
 * - All references in task-router active table point to existing skills
 *
 * Exit code: 0 if clean, 1 if any failures.
 */

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const PROMPTS_ROOT = join(REPO_ROOT, 'prompts');

const REQUIRED_FRONTMATTER = ['name', 'description', 'category', 'version'];
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

const DESCRIPTION_MAX = 120;
const LENGTH_MIN = 80;
const LENGTH_MAX = 310;

const LEAKAGE_TERMS = [
  /\bozzeron\b/i,
  /\bproject-a\b/i,
  /\bproject-b[-\s]?fit\b/i,
  /\bmed[-\s]?project-c\b/i,
  /\bacme-data\b/i,
  /\betl-tool\b/i,
  /\bproject-d\b/i,
];

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

function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/);
  if (!match) return null;
  const fm = {};
  for (const line of match[1].split(/\r?\n/)) {
    const m = line.match(/^([a-z_]+):\s*(.*)$/i);
    if (!m) continue;
    const key = m[1];
    const val = m[2].trim();
    if (val.startsWith('[') && val.endsWith(']')) {
      fm[key] = val
        .slice(1, -1)
        .split(',')
        .map((s) => s.trim().replace(/^['"]|['"]$/g, ''))
        .filter(Boolean);
    } else {
      fm[key] = val.replace(/^['"]|['"]$/g, '');
    }
  }
  return fm;
}

function extractSectionHeadings(body) {
  return body
    .split(/\r?\n/)
    .filter((line) => /^## /.test(line))
    .map((line) => line.trim());
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
  const linkPattern = /\]\((\.\.[^)]*SKILL\.md)\)/g;
  let m;
  while ((m = linkPattern.exec(body)) !== null) {
    const target = resolve(dirname(fromPath), m[1]);
    if (!existsSync(target)) {
      failures.push(`broken link to ${m[1]}`);
    }
  }
  return failures;
}

function checkLeakage(content) {
  const hits = [];
  for (const re of LEAKAGE_TERMS) {
    const m = content.match(re);
    if (m) hits.push(m[0]);
  }
  return hits;
}

function lintSkill(skill) {
  const content = readFileSync(skill.path, 'utf8');
  const lineCount = content.split(/\r?\n/).length;
  const failures = [];

  const fm = parseFrontmatter(content);
  if (!fm) {
    failures.push('missing or malformed YAML frontmatter');
    return failures;
  }

  for (const key of REQUIRED_FRONTMATTER) {
    if (!fm[key]) failures.push(`missing frontmatter field: ${key}`);
  }

  if (fm.name && fm.name !== skill.name) {
    failures.push(`frontmatter name "${fm.name}" != directory name "${skill.name}"`);
  }
  if (fm.description && fm.description.length > DESCRIPTION_MAX) {
    failures.push(`description ${fm.description.length} > ${DESCRIPTION_MAX} chars`);
  }
  if (fm.category && fm.category !== skill.category) {
    failures.push(`frontmatter category "${fm.category}" != directory category "${skill.category}"`);
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

function main() {
  const skills = findSkillFiles();
  const skillIds = skills.map((s) => `${s.category}/${s.name}`);
  let totalFailures = 0;

  console.log(`Linting ${skills.length} skills...\n`);

  for (const skill of skills.sort((a, b) =>
    `${a.category}/${a.name}`.localeCompare(`${b.category}/${b.name}`),
  )) {
    const failures = lintSkill(skill);
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

  const routerFailures = checkRouterReferences(skillIds);
  if (routerFailures.length === 0) {
    console.log('  PASS  task-router active table references existing skills');
  } else {
    console.log('  FAIL  task-router');
    for (const f of routerFailures) console.log(`        - ${f}`);
    totalFailures += routerFailures.length;
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
