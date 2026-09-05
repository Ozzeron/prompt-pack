#!/usr/bin/env node
/**
 * Activation eval for skill descriptions.
 *
 * The description is the only thing a host sees before deciding whether to open a skill,
 * so it is the one part of the pack that can be measured without running an agent. This
 * script scores every labelled query in evals/descriptions/cases.yaml against the pack's
 * descriptions and reports top-1 accuracy plus each miss.
 *
 * Two modes:
 *
 *   default (--static)  A deterministic BM25-style scorer over descriptions only. This is
 *                       a PROXY, not a model: it measures whether a description carries
 *                       discriminating vocabulary for the query, which is exactly what an
 *                       under-specified description lacks. It is fast, offline, and
 *                       reproducible, so it can gate CI. It does NOT prove a real host
 *                       routes the same way.
 *   --llm               Asks the actual matcher: builds the skill index (name +
 *                       description for all skills, the same ~2% of context a host loads)
 *                       and has the `claude` CLI pick one skill per query in headless
 *                       mode. Requires the CLI on PATH; skipped, never faked, otherwise.
 *
 * Negative-clause handling: a description ends with "Not for X (sibling-skill)". A bag of
 * words would read that sibling's name as a match, so tokens that appear ONLY after the
 * negative marker score negatively instead of positively — the same way a reader treats
 * an exclusion.
 *
 * Exit code: 0 if accuracy >= ACCURACY_FLOOR and no inherit-only/legacy skill won a case.
 */

import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import YAML from 'yaml';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const PROMPTS_ROOT = join(REPO_ROOT, 'prompts');
const CASES_PATH = join(REPO_ROOT, 'evals', 'descriptions', 'cases.yaml');

// Ratchet, not a target: raise it when descriptions improve, never lower it to make a red
// run green. A miss is a description problem until proven otherwise.
const ACCURACY_FLOOR = 0.95;

const NEGATIVE_MARKER = /\b(not for|don't use|do not use)\b/i;
const STOPWORDS = new Set([
  'the', 'and', 'for', 'with', 'use', 'when', 'your', 'this', 'that', 'from', 'into',
  'are', 'not', 'but', 'can', 'you', 'our', 'has', 'have', 'was', 'its', 'it', 'a', 'an',
  'of', 'to', 'in', 'on', 'is', 'do', 'i', 'me', 'my', 'we', 'us', 'at', 'by', 'or',
  'here', 'there', 'what', 'why', 'how', 'all', 'any', 'out', 'off', 'per', 'via',
  'need', 'needs', 'want', 'wants', 'like', 'just', 'now', 'then', 'than', 'them',
  'add', 'get', 'set', 'make', 'take', 'give', 'tell', 'show', 'says', 'said',
  // Indefinites: they carry no routing signal, and stemming them ("anything" -> "anyth")
  // creates matches out of nothing — one of these alone once decided a case.
  'anything', 'something', 'nothing', 'everything', 'someone', 'anyone', 'else',
  'idea', 'clearly', 'only', 'cannot', 'does', 'about', 'over', 'more', 'some',
]);

// Light stemmer: plural and common verb endings only. Enough to tie "migrations" to
// "migration" and "reviews" to "review" without pulling in a dependency. Suffix
// stripping stops at 4 characters so short words are not ground into shared prefixes.
function stem(token) {
  const plural = token
    .replace(/(ies)$/, 'y')
    .replace(/(sses|shes|ches|xes)$/, 's')
    .replace(/([^s])s$/, '$1');
  const verbal = plural.replace(/(ing|ed)$/, '');
  return verbal.length >= 4 ? verbal : plural;
}

function tokenize(text) {
  return String(text)
    .toLowerCase()
    .split(/[^a-z0-9._/]+/)
    .flatMap((t) => (t.includes('.') || t.includes('/') ? [t, ...t.split(/[./]/)] : [t]))
    .map((t) => t.replace(/^[._/]+|[._/]+$/g, ''))
    .filter((t) => t.length >= 2 && !STOPWORDS.has(t))
    .map(stem)
    .filter(Boolean);
}

function loadSkills() {
  const skills = [];
  for (const category of readdirSync(PROMPTS_ROOT)) {
    const categoryPath = join(PROMPTS_ROOT, category);
    if (!statSync(categoryPath).isDirectory()) continue;
    for (const name of readdirSync(categoryPath)) {
      const file = join(categoryPath, name, 'SKILL.md');
      if (!existsSync(file)) continue;
      const content = readFileSync(file, 'utf8');
      const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/);
      if (!m) continue;
      const fm = YAML.parse(m[1]);
      const description = String(fm.description || '');
      const split = description.search(NEGATIVE_MARKER);
      skills.push({
        id: `${category}/${name}`,
        name,
        description,
        activation: (fm.metadata || {})['pp-activation'] || 'native',
        positive: tokenize(`${name} ${split === -1 ? description : description.slice(0, split)}`),
        negative: split === -1 ? [] : tokenize(description.slice(split)),
      });
    }
  }
  return skills.sort((a, b) => a.id.localeCompare(b.id));
}

/** BM25 over the positive half of each description, minus a penalty for negative-only hits. */
function buildScorer(skills) {
  const K1 = 1.2;
  const B = 0.75;
  const NEGATIVE_PENALTY = 0.6;

  const docFreq = new Map();
  for (const s of skills) {
    for (const t of new Set(s.positive)) docFreq.set(t, (docFreq.get(t) || 0) + 1);
  }
  const avgLen = skills.reduce((sum, s) => sum + s.positive.length, 0) / skills.length;
  const idf = (t) => {
    const n = docFreq.get(t) || 0;
    return Math.log(1 + (skills.length - n + 0.5) / (n + 0.5));
  };

  return function score(skill, queryTokens) {
    const tf = new Map();
    for (const t of skill.positive) tf.set(t, (tf.get(t) || 0) + 1);
    const negative = new Set(skill.negative);
    let total = 0;
    for (const q of new Set(queryTokens)) {
      const f = tf.get(q) || 0;
      if (f > 0) {
        total +=
          idf(q) * ((f * (K1 + 1)) / (f + K1 * (1 - B + B * (skill.positive.length / avgLen))));
      } else if (negative.has(q)) {
        // The description explicitly disclaims this vocabulary.
        total -= NEGATIVE_PENALTY * idf(q);
      }
    }
    return total;
  };
}

function rankStatic(skills, query) {
  const score = buildScorer(skills);
  const q = tokenize(query);
  return skills
    .map((s) => ({ id: s.id, activation: s.activation, score: score(s, q) }))
    .sort((a, b) => b.score - a.score);
}

// --- LLM mode ---------------------------------------------------------------------

function claudeAvailable() {
  const probe = spawnSync(process.platform === 'win32' ? 'where' : 'which', ['claude'], {
    encoding: 'utf8',
  });
  return probe.status === 0;
}

/**
 * Ask the real matcher. The prompt goes in on stdin, not as an argv string: the index is
 * multi-line and quoted, and a shell-concatenated argument mangles it.
 *
 * Throws on anything that is not a usable answer (CLI error, auth failure, unrecognised
 * id). Reporting a broken CLI as "0% accuracy" would be worse than reporting nothing.
 */
function rankLlm(skills, query, byId) {
  const index = skills.map((s) => `- ${s.id}: ${s.description}`).join('\n');
  const prompt = [
    'You are the skill matcher of a coding agent. Below is the installed skill index',
    '(name and description only, exactly what you see before a skill is opened).',
    '',
    index,
    '',
    `User request: "${query}"`,
    '',
    'Reply with the single skill id that should activate, or the word none if no skill fits.',
    'Reply with the id and nothing else.',
  ].join('\n');

  const res = spawnSync('claude', ['-p'], { input: prompt, encoding: 'utf8', shell: true });
  const out = (res.stdout || '').trim();
  if (res.status !== 0 || !out) {
    throw new Error(`claude CLI failed (exit ${res.status}): ${(out || res.stderr || '').split('\n')[0]}`);
  }
  const answer = out.split(/\s+/)[0].replace(/[`'".,]/g, '');
  if (answer !== 'none' && !byId.has(answer)) {
    throw new Error(`claude CLI returned an unrecognised answer: ${out.slice(0, 120)}`);
  }
  return [{ id: answer, activation: byId.get(answer)?.activation || 'native', score: 1 }];
}

// --- main -------------------------------------------------------------------------

function main() {
  const useLlm = process.argv.includes('--llm');
  const verbose = process.argv.includes('--verbose');
  // --limit N runs the first N cases. The full suite in --llm mode is one CLI session per
  // case, so a smoke run of the real matcher stays affordable while the static suite keeps
  // gating every push.
  const limitArg = process.argv.find((a) => a.startsWith('--limit'));
  const limit = limitArg ? Number(limitArg.split('=')[1] ?? process.argv[process.argv.indexOf(limitArg) + 1]) : 0;

  const skills = loadSkills();
  const byId = new Map(skills.map((s) => [s.id, s]));
  let cases = YAML.parse(readFileSync(CASES_PATH, 'utf8')).cases || [];
  if (limit > 0) cases = cases.slice(0, limit);

  if (useLlm && !claudeAvailable()) {
    console.error('eval-descriptions --llm needs the `claude` CLI on PATH. Skipping (not faking).');
    process.exit(1);
  }

  const mode = useLlm ? 'llm (real matcher)' : 'static (deterministic proxy)';
  console.log(`Description activation eval: ${cases.length} cases, ${skills.length} skills, mode=${mode}\n`);

  const misses = [];
  const wrongActivation = [];
  let hits = 0;
  let scored = 0;
  const skipped = [];

  for (const c of cases) {
    if (!byId.has(c.expect)) {
      misses.push({ ...c, got: '(unknown skill in cases.yaml)', runnerUp: '' });
      scored += 1;
      continue;
    }
    // A case marked llm_only shares no vocabulary with any description by nature — only
    // semantic inference resolves it, so scoring it in static mode would measure the proxy
    // rather than the pack. It still runs (and still counts) under --llm.
    if (c.llm_only && !useLlm) {
      skipped.push(c);
      continue;
    }
    scored += 1;
    let ranked;
    if (useLlm) {
      try {
        ranked = rankLlm(skills, c.query, byId);
      } catch (e) {
        // Abort rather than fold a broken matcher into the accuracy number.
        console.error(`
LLM mode aborted: ${e.message}`);
        console.error('Re-authenticate the claude CLI (`claude` then /login) and re-run. No accuracy reported.');
        process.exit(2);
      }
    } else {
      ranked = rankStatic(skills, c.query);
    }
    // Everything at or below zero means no description carried discriminating vocabulary;
    // reporting the arbitrary first element as "the match" would hide that.
    const top = ranked[0] && ranked[0].score > 0 ? ranked[0] : null;
    const ok = top && top.id === c.expect;
    if (ok) hits += 1;
    else {
      misses.push({
        ...c,
        got: top ? top.id : '(no discriminating vocabulary in any description)',
        runnerUp: ranked[1] && ranked[1].score > 0 ? `${ranked[1].id} (${ranked[1].score.toFixed(2)})` : '',
      });
    }
    // A foundation skill winning a task query means the pack would load rules as if they
    // were work — the failure mode pp-activation exists to prevent.
    const winner = top && byId.get(top.id);
    if (winner && winner.activation !== 'native') {
      wrongActivation.push(`"${c.query}" -> ${top.id} (pp-activation: ${winner.activation})`);
    }
    if (verbose && !useLlm) {
      const line = ranked
        .slice(0, 3)
        .map((r) => `${r.id}:${r.score.toFixed(2)}`)
        .join('  ');
      console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${c.query}\n        ${line}`);
    }
  }

  const accuracy = scored === 0 ? 0 : hits / scored;
  if (!verbose) {
    for (const m of misses) {
      console.log(`  FAIL  "${m.query}"`);
      console.log(`        expected ${m.expect}, matched ${m.got}${m.runnerUp ? `, runner-up ${m.runnerUp}` : ''}`);
    }
  }

  console.log();
  console.log(`top-1 accuracy: ${hits}/${scored} = ${(accuracy * 100).toFixed(1)}% (floor ${(ACCURACY_FLOOR * 100).toFixed(0)}%)`);
  if (skipped.length > 0) {
    console.log(`skipped in static mode: ${skipped.length} case(s) that only semantic inference can resolve`);
    for (const s of skipped) console.log(`  - "${s.query}" -> ${s.expect} (${s.why || 'no reason recorded'})`);
  }

  if (wrongActivation.length > 0) {
    console.log('\nNon-native skills winning a case (must never happen):');
    for (const w of wrongActivation) console.log(`  - ${w}`);
  }

  if (!useLlm) {
    console.log(
      '\nNote: static mode is a keyword-discrimination proxy, not a model. It catches ' +
        'descriptions that lack distinguishing vocabulary; it does not prove how a host routes. ' +
        'Run with --llm before claiming real activation accuracy.',
    );
  }

  if (accuracy < ACCURACY_FLOOR || wrongActivation.length > 0) {
    console.log('\nFAILED');
    process.exit(1);
  }
  console.log('\nPASSED');
  process.exit(0);
}

main();
