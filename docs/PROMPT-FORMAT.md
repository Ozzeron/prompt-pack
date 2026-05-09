# Prompt format

Every prompt in `prompts/<category>/<name>/SKILL.md` follows this schema. The format is designed to:

- be picked up by OpenClaw / ClawHub as a skill
- be compatible with Cursor `rules` and Claude Code `agents` with minimal massage
- be readable and copy-pasteable by humans
- enforce token discipline by structure

## Schema

```markdown
---
name: <kebab-case-id>
description: <one-line, what this prompt is for; what triggers it>
category: <architecture | review | interface | delivery | meta>
version: 0.1.0
triggers: [<short trigger phrases or task types>]
applies_to: [<cursor, claude-code, openclaw, generic>]
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

## Required fields in frontmatter

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | string | yes | kebab-case, must match directory name |
| `description` | string | yes | one-line summary, **≤ 120 characters**; main agents see this |
| `category` | enum | yes | architecture / review / interface / delivery / meta |
| `version` | semver | yes | bump on behaviour change |
| `triggers` | string[] | no | hints for orchestrators |
| `applies_to` | string[] | no | which surfaces this is verified on |

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
- power the `task-router` orchestrator
- convert prompts to Cursor/Claude Code formats
- validate prompt quality on PRs (linting)

The body is structured so models (especially weaker ones) parse it consistently
and don't drift between sections.

## Length guidance

- A skill file should usually fit in **80–250 lines**. If it grows beyond that,
  split into a smaller core skill + supporting docs in the same directory.
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
