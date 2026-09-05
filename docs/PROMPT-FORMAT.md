# Prompt format

Every prompt in `prompts/<category>/<name>/SKILL.md` follows this schema. The format is designed to:

- be picked up by OpenClaw / ClawHub as a skill
- be compatible with Cursor `rules` and Claude Code `agents` with minimal massage
- be readable and copy-pasteable by humans
- enforce token discipline by structure

## Schema

```markdown
---
name: <kebab-case-id, matching the directory name>
description: "<what it does. Use when <literal triggers>. Not for <near-miss siblings>.>"
license: MIT
metadata:
  pp-category: <architecture | review | interface | delivery | meta | infra>
  pp-version: "0.1.0"
  pp-activation: <native | inherit-only | legacy>
  pp-surfaces: "<openclaw, cursor, claude-code>"
---

# <Role title>

<One paragraph: who the agent is, what mode they operate in.>

## When to use

- <Concrete trigger 1>
- <Concrete trigger 2>

## Scope

In scope:
- <thing 1>
- <thing 2>

Out of scope:
- <thing 1>
- <thing 2>

## Token discipline

- Never read: `node_modules/`, `.next/`, `dist/`, `.git/`, `__pycache__/`
- Before reading files larger than 50KB: explain why and ask
- Prefer `grep`/scripts over reading large files raw
- <category-specific limits>

## Process

1. <Step 1>
2. <Step 2>
3. <Step 3>

## Output format

<Describe expected sections, headings, or response structure>

## Anti-patterns

- ❌ <thing not to do>
- ❌ <thing not to do>

## Notes

<Optional: caveats, version notes, related prompts>
```

## Frontmatter

The top level is fixed by the [Agent Skills specification](https://agentskills.io/specification):
only `name`, `description`, `license`, `compatibility`, `metadata`, and `allowed-tools` may
appear there. Everything pack-specific lives under `metadata` as a `pp-`-prefixed **string**
(the spec defines metadata as a map of string to string, so no lists and no bare numbers).
Inventing a top-level key still loads in Claude Code, but it fails `skills-ref validate` and
stops being portable — the linter rejects it.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | string | yes | kebab-case, must match directory name |
| `description` | string | yes | activation surface — see the rules below |
| `license` | string | yes here | `MIT`, matching the repo licence |
| `metadata.pp-category` | enum | yes | architecture / review / interface / delivery / meta / infra; must match the directory |
| `metadata.pp-version` | semver string | yes | bump on every behaviour change (CI gate) |
| `metadata.pp-activation` | enum | yes | `native` · `inherit-only` · `legacy` |
| `metadata.pp-surfaces` | string | no | comma-separated surfaces the skill is verified on |

`pp-activation` values:

- **`native`** — the host discovers it from `description` alone. Almost every skill.
- **`inherit-only`** — pulled in by another skill's `## Inherits` section and never matched
  against a user request. Its description must say so, or a host will load foundation rules
  as if they were a task.
- **`legacy`** — kept for pre-Agent-Skills flows (orchestrator routing). Excluded from
  native install targets. Currently only `meta/task-router`.

There is no `triggers` field. It was a pre-standard invention that no host reads: on a
native host the description IS the trigger surface, so trigger phrases belong inside it as
literal keywords.

### Description rules

The description is the only part of a skill loaded before the host decides whether to open
it, which makes it the highest-leverage 400 characters in the file. Required shape:

1. **What it does**, third person, concrete nouns — not "helps with databases".
2. **`Use when …`** with the words a user actually types. Literal beats paraphrase:
   `containerise`, `RLS`, `auth.uid()`, `without downtime`, `flaky in CI`, `pnpm add`.
3. **A negative trigger** (`Not for …`) naming the sibling skill that would otherwise steal
   the activation. Overlapping skills are the main cause of wrong routing in a pack this
   dense: `code-review` vs the `*-audit` skills, `doc-writer` vs `ai-agent-docs`,
   `database-schema` vs `database-migrations` vs `database-review`.

Enforced by the linter: 120–500 characters, a `Use when` clause, a negative clause,
ASCII only (`install.ps1` rewrites this line under Windows PowerShell 5.1, which
double-encodes non-ASCII), and no two descriptions above 0.5 Jaccard token similarity.

Every new or reworded description also needs cases in `evals/descriptions/cases.yaml`
— at least one obvious query, one non-obvious phrasing, and one near-miss that must route
elsewhere. `npm run eval:descriptions` gates CI at 95% top-1.

## Section order

Non-meta skills follow this exact section order. Required headings are bold; the others
are conventional but optional. Other content headings can appear between them.

1. Title heading + role paragraph
2. **`## When to use`**
3. **`## Scope`** (see Scope structure below)
4. **`## Inherits`**
5. **`## Token discipline (specific)`**
6. `## Process` (optional — some skills replace a single Process with multiple topic
   sections like "Golden rules", "Patterns", "Workflow". When omitted, the Output format
   defines the structured deliverable instead.)
7. **`## Output format`**
8. **`## Anti-patterns`**
9. `## Notes` (optional)

### Scope structure

`## Scope` is a single H2 heading. "In scope" and "Out of scope" are **subsections inside it**,
rendered as labelled lists (NOT separate H2 headings):

```markdown
## Scope

In scope:
- <thing>
- <thing>

Out of scope:
- <thing>
- <thing>
```

Do not write `## In scope` or `## Out of scope` as separate H2 headings. The single
`## Scope` heading owns the section; its body uses bold labels with bullet lists.

External validators that look for a `## In scope` heading are using a different convention
than this pack and will report false negatives. The linter in `scripts/lint-skills.mjs`
uses the correct rules.

### Meta skill exceptions

Meta skills (`category: meta`) are the inheritance roots and may legitimately omit:

- `## Inherits` — they are what others inherit
- `## Output format` when the skill produces no direct output (e.g. cross-cutting rules
  the agent internalises rather than emits)
- `## Token discipline (specific)` when the entire skill *is* the token discipline rules

They still must include: role paragraph, `## When to use`, the rule body itself (in any
appropriate heading structure), and `## Anti-patterns`. Diverging beyond this requires a
one-line justification in `## Notes`.

The four current meta skills (`engineering-principles`, `reuse-before-create`,
`token-discipline`, `task-router`) are reference templates for how meta skills can deviate
legitimately.

## Why structured

The frontmatter is machine-readable so tools can:

- generate a catalog/index
- power the `task-router` orchestrator on legacy (non-Agent-Skills) hosts
- convert prompts to Cursor/Claude Code formats
- validate prompt quality on PRs (linting)

The body is structured so models (especially weaker ones) parse it consistently
and don't drift between sections.

## Progressive disclosure

`SKILL.md` is loaded in full on every activation, so it holds only what every run needs:
scope, process, gotchas, output format, anti-patterns. Anything conditional goes into
`references/*.md` — output templates, per-branch checklists, coverage passes, worked
examples (`references/EXAMPLES.md`).

Each reference file must be linked from `SKILL.md` on a line that states **when** to read
it:

```markdown
> **Detail:** read [Coverage areas](references/coverage-areas.md) when you work a coverage
> pass: injection, authz, secrets, transport, CSRF, dependencies, uploads, config.
```

"See references/ for details" is not acceptable and the linter rejects it: without a
condition the agent cannot tell whether this run needs the file, so it either loads
everything (defeating the point) or nothing (losing the content). The linter also fails a
reference file that nothing links to, one left at the skill root instead of `references/`,
and one over 250 lines.

Note for flat install targets (`raw`, `cursor-rules`, `codex-agents-md`, `claude-code`
subagents): they write a single file per skill and cannot carry `references/`. The
directory-based targets (`claude-skills`, `agents`, `cursor`, `codex`, `openclaw`) and the
plugin install copy them verbatim.

## Length guidance

- `SKILL.md` must be **80–240 lines** (linted). The spec ceiling is 500 lines / 5,000
  tokens for the whole file; the tighter budget exists because this content loads on every
  activation. Past 240 lines, move conditional material into `references/`.
- Keep the role statement to **one paragraph**. Long preambles waste tokens
  on every invocation.
- Token-discipline section is mandatory and non-negotiable.

## Writing principle: rules that must survive compression

Empirical testing of v0.1.x skills against real coding tasks surfaced a consistent
failure mode: the **output format** of a skill (severity tables, deliverable templates,
fenced report blocks) survives compression into the agent's working memory, but **process
steps written as prose in the middle of the skill** drop out under load. Result: the
final output looks correct in shape, but the discipline ("read the diff first, not the
full files", "check project conventions", "do all four review passes") quietly didn't
run.

This is not an agent failure to fix in the runtime; it is a **skill-authoring failure**
to fix in the file. Apply this principle when writing or editing any skill:

- **Rules that must run go at the top of the file as structured checklists, not as
  prose later in the file.** A `## Preflight` section immediately after the role
  paragraph, before `## When to use`, is the canonical place for these. See
  `prompts/review/code-review/SKILL.md` for the reference shape.
- **Each Preflight item is a `- [ ]` checkbox** with a single concrete action and a
  named failure mode. Not a paragraph of guidance. The goal is that the agent reads
  the box, performs the action, and ticks it before continuing.
- **Routing conditionals belong in Preflight, not in `## When to use`.** "Is this a
  diff or existing code?" decides which skill should run at all; it cannot live in
  prose readers may skim.
- **Reading plans belong in Preflight.** "Which files, in what order, with what stop
  condition" is the discipline that prevents the agent from reading three files in
  full because they were mentioned. Force the agent to commit to the plan before
  opening the first file.
- **Multi-pass workflows enumerate the passes by name in Preflight, even if they are
  detailed later in `## Process`.** The Preflight line guarantees the pass count
  reaches the compressed summary; the Process section provides the detail when the
  agent re-reads under low load.
- **Output-format-only skills are exempt.** Pure summary or formatter skills (e.g.
  `delivery/handoff`) are output-only by design and don't need a Preflight section.
  Discipline-bearing skills (architecture, review, audit) do.

The linter does not enforce a `## Preflight` section yet. It is a **content rule**, not
a format rule — enforced through the reviewer checklist in `CONTRIBUTING.md`. If a new
discipline-bearing skill ships without a Preflight, the reviewer rejects it for that
reason and points the contributor at this section.
