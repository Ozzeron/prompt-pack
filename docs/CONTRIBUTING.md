# Contributing

prompt-pack is a curated **Agent Skills library**, not a prompt directory.

The pack is intentionally small. Every skill in `prompts/` earns its place by
preventing a recurring AI failure mode (duplicate components, fresh utilities for
things that already exist, convention drift, confident hallucinations on review).
Contributions are welcome — but the bar is "does this close a failure mode that no
existing skill covers", not "is this a nice prompt".

## What belongs here

A new skill earns its place when:

1. **It addresses a recurring AI failure mode.** "AI agents tend to do X wrong" is
   the strongest motivation. Vague "best practices" skills are not.
2. **It's not already covered.** Search the skill catalogue. If 80% overlaps an
   existing skill, improve that one instead of adding a new one.
3. **It has clear scope and out-of-scope.** A skill that "helps with frontend
   things" is too broad. A skill that "builds a frontend feature end-to-end" is
   right-sized.
4. **It produces actionable output.** Skills that emit buzzwords without specific
   recommendations don't ship.

## What does not belong

- "You are a senior X" persona prompts without operational guidance
- Personal preferences without justification ("always use Tailwind")
- Anything tied to a specific company, product, or non-public service
- Single-use prompts ("write a haiku about React")

## Before proposing a new skill

1. **Open an issue first** for any new skill or significant change to an existing
   one. Drive-by PRs that add a new skill without discussion will likely be
   declined — not because the skill is bad, but because the curated skill set has
   to stay coherent.
2. **Search the catalogue.** Read `prompts/<category>/<name>/SKILL.md` for anything
   adjacent. If your idea is a 20% extension of an existing skill, propose editing
   it instead of adding a sibling.
3. **Branch from `main`**, name it `skill/<category>-<name>` for new skills or
   `fix/<area>-<short-desc>` for fixes.
4. **One skill per PR.** Touching multiple skills in one PR is OK only when they
   share a meta-layer change.

## Skill format

Every skill follows the schema in [`docs/PROMPT-FORMAT.md`](PROMPT-FORMAT.md). The
SKILL.md body is the system prompt the host loads at activation time. Required:

- YAML frontmatter (`name`, `description`, `category`, `version`)
- One-paragraph role statement
- `## When to use` with concrete triggers
- `## Scope` (in / out)
- `## Inherits`
- `## Token discipline (specific)`
- `## Output format`
- `## Anti-patterns`
- `## Preflight` checklist at the top for discipline-bearing skills (architecture,
  review, audit). Output-only skills like `delivery/handoff` are exempt. See the
  "rules that must survive compression" section in `PROMPT-FORMAT.md` for why.

Skills should typically fit in 80–250 lines. Larger skills split into smaller ones
or move detail into supporting files in the same directory (`EXAMPLES.md`,
`CHANGELOG.md`).

### Inheritance

Coding skills must declare what they inherit:

```markdown
## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — DRY, file size, type safety
- [`meta/reuse-before-create`](../../meta/reuse-before-create/SKILL.md) — search before adding
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — what to read and not to
```

Don't restate inherited rules; reference them. Skills that conflict with the meta
layer should justify the conflict, not silently override.

## Writing a good description

The frontmatter `description` field is the **primary activation surface** for
native Agent Skills hosts (Cursor 2.4+, Codex CLI, anything that reads
`.agents/skills/<name>/SKILL.md` directly). The host's own skill matcher reads the
description first and decides whether to load the body. A vague description means
the skill never activates, no matter how good the body is.

Write the description as if it were a one-line routing rule, not a tagline.

- **Bad:** "Helps write better frontend code."
- **Good:** "Build frontend features by reusing existing routing, data, form,
  state, and UI conventions before creating new artifacts."

- **Bad:** "Reviews your pull requests."
- **Good:** "Code review on a diff or PR: severity-classified findings, file +
  line citations, correctness/security/maintainability focus."

- **Bad:** "Database stuff."
- **Good:** "Write safe, reversible, backward-compatible database migrations
  (expand-then-contract, no downtime, no lock storms)."

Rules of thumb:

- Lead with the verb the user would say ("Build...", "Review...", "Plan...").
- Name the artifact, the input, and the discipline in one line.
- Keep it ≤ 120 characters (the linter enforces this).
- No marketing adjectives ("powerful", "world-class"). They cost tokens and
  carry no routing signal.

## Activation and routing

prompt-pack supports two activation models. New skills should work in both:

1. **Native skill discovery** (`cursor`, `agents` targets, Cursor 2.4+, Codex CLI,
   GitHub Copilot). The host scans installed skills, reads frontmatter
   `description` fields, and activates matches automatically. There is no router;
   the description **is** the router. This is the default for new contributions.

2. **Legacy / orchestrated flows** (`cursor-rules`, `claude-code`, `openclaw`,
   `codex-agents-md`). These targets ship `meta/task-router/SKILL.md` as an
   explicit orchestrator. The router maps user intents to skills and decides when
   to spawn subagents. The Codex `AGENTS.md` bridge also uses task-router rows to
   build composed-flow routing.

If your skill is task-facing, the frontmatter description has to carry it on the
native targets and the task-router table has to carry it on the legacy and Codex
bridge targets. Both must be updated.

## Installer and profile checks

When you add a skill, decide which profiles it belongs to and edit **both**
installers in lockstep. The linter cross-checks parity between them.

- `install.ps1` — PowerShell installer (`$Script:Profiles` hashtable).
- `install.sh` — Bash installer (heredoc-style profile blocks).

The profiles are: `minimal`, `nextjs`, `backend`, `supabase`, `fullstack`. The
`all` profile is built at runtime from every skill in `prompts/`.

If the skill is foundation-level (always-on Cursor rule) or excluded from native
Cursor/Codex discovery (like `meta/task-router`), update the relevant lists in
`install.ps1` (`$Script:CursorAlwaysApplySkills`, `$Script:CursorAgentsFilterSkills`,
etc.) and mirror in `install.sh`.

If you change profile counts, update the README profile table at the same time —
the linter checks the numbers match.

## Linter

Run the linter locally before opening a PR:

```bash
npm run lint
```

It checks every skill against the format contract: required frontmatter fields,
description length, required sections in order, internal link integrity, length
bounds, project-specific leakage, installer profile parity between
`install.ps1` and `install.sh`, README profile counts, and task-router references.
It also verifies that every inline `<category>/<name>` skill reference in any skill
body resolves to a real skill (not just those in task-router), and that no two skill
descriptions are near-duplicates (Jaccard token-overlap similarity below a calibrated
threshold), since descriptions drive native skill matching. If `npm run lint` is green,
your skill is structurally valid; the reviewer can focus on content.

The linter is a single file with no dependencies (`scripts/lint-skills.mjs`),
works on any Node 18+.

## Release testing

For changes that touch the installer, the Codex AGENTS.md bridge, routing logic,
or profile membership, run the relevant regression brief from
[`docs/release-testing/`](release-testing/) before requesting review. The current
brief covers the Codex target end-to-end (installer, layout, AGENTS.md content,
skill discovery, routing, cross-skill links). It is environment-specific (Windows
/ PowerShell / one Codex CLI version) and intentionally not part of CI.

Deterministic installer/format checks may move to GitHub Actions in a future
release. LLM-based checks (skill activation, routing intents, composed flows)
remain manual because they require network access and produce non-deterministic
results.

## PR checklist

Before opening a PR:

**Skill content**
- [ ] `npm run lint` passes
- [ ] Frontmatter has all required fields (name, description, category, version)
- [ ] `name` matches the directory name (kebab-case)
- [ ] `description` is one line, ≤ 120 chars, and clearly supports native skill
      discovery (see "Writing a good description")
- [ ] `version` follows semver, starts at `0.1.0`
- [ ] `## When to use` lists concrete triggers; `## Scope` "Out of scope" lists
      what NOT to invoke for
- [ ] `## Token discipline (specific)` is present (or inherits-only with a
      one-line note)
- [ ] `## Anti-patterns` section has at least 5 items
- [ ] Discipline-bearing skills (architecture, review, audit) ship a `## Preflight`
      checklist; output-only skills are exempt
- [ ] If the skill produces code recommendations, examples use idiomatic, modern
      syntax
- [ ] No company-specific or product-specific references unless universally
      applicable

**Activation and routing**
- [ ] If the skill is task-facing, its `description` clearly supports native
      skill discovery on Cursor 2.4+ / Codex / Copilot
- [ ] If legacy or orchestrated flows need it, the routing row is added to
      `prompts/meta/task-router/SKILL.md`
- [ ] If the Codex `AGENTS.md` bridge needs a route or composed flow, the
      relevant template or regression brief is updated

**Installer and profiles**
- [ ] Skill is included in the intended profile(s) in **both** `install.ps1`
      **and** `install.sh`
- [ ] If profile counts changed, README profile table is updated
- [ ] Installer dry-run was checked for affected targets

**Release testing**
- [ ] For installer / Codex bridge / routing / profile changes: relevant brief
      from `docs/release-testing/` was run (where one exists)

## Reviewer checklist

When reviewing a skill PR, work through the following gates in order. The first
failure blocks merge; do not soften a no into a maybe.

**1. Justification**
- [ ] The PR description names the recurring AI failure mode this skill prevents
      (or, for a fix, the failure mode the existing skill missed). "Best
      practices" alone is not enough.
- [ ] If a new skill: the issue thread shows that no existing skill (or extension
      of one) could cover this.

**2. Scope hygiene**
- [ ] `## When to use` lists concrete triggers a real user might phrase, not
      abstract categories like "complex task".
- [ ] "Out of scope" is non-empty and lists at least one tempting-but-rejected
      use.
- [ ] No silent overlap with another skill's scope. If overlap exists, one skill
      points at the other.

**3. Discipline content**
- [ ] Anti-patterns section has ≥ 5 items, each describing a specific failure
      ("❌ X because Y"), not a generic "bad practice".
- [ ] Token-discipline section is present and tells the agent what NOT to read
      for this skill.
- [ ] Output format is concrete (template, table, or worked example), not just
      "a clear summary".
- [ ] **Preflight section present for discipline-bearing skills.** Architecture,
      review, and audit skills must open with a `## Preflight` checklist of the
      routing, reading-plan, conventions, and pass-count items that have to run
      before any file is opened. See `docs/PROMPT-FORMAT.md` ("Writing principle:
      rules that must survive compression") and
      `prompts/review/code-review/SKILL.md` for the reference shape. Pure
      output-only skills (e.g. handoff) are exempt.
      *Migration note:* the Preflight requirement applies in full to **new**
      discipline-bearing skills. Existing v0.1.x skills are migrated gradually,
      one at a time, after empirical testing on a real task. Reviewing an
      existing skill that does not yet have one is not a blocker; reviewing a
      new skill that omits one is.

**4. Activation surface**
- [ ] `description` reads as a routing rule, not a tagline (verb first, names
      the artifact, names the discipline).
- [ ] If the skill is meant for native discovery on `cursor` / `agents`
      targets, the description carries enough signal that the host's matcher
      can pick it up without a router.

**5. Inherits and references**
- [ ] If the skill creates code, it inherits `meta/engineering-principles`,
      `meta/reuse-before-create`, and `meta/token-discipline`.
- [ ] Every linked skill exists at the path given (the linter enforces this;
      trust it).
- [ ] If the skill is task-facing, `meta/task-router` has a row pointing to it
      (or this PR adds one).

**6. Trigger discipline**
- [ ] No `triggers: [always]` unless the skill is genuinely a baseline rule for
      all turns.
- [ ] Skills meant to be loaded only by reference use
      `triggers: [inherit-only]` (the linter enforces this is the sole
      trigger).
- [ ] Triggers contain phrases users actually emit, not internal jargon.

**7. Stack-agnosticism vs leakage**
- [ ] No project, company, or client name (the linter blocks the obvious ones;
      check for new ones too).
- [ ] Stack-specific guidance (Next.js App Router, Supabase RLS, etc.) is
      allowed when it illustrates a discipline rule, not when it ties the
      skill to one stack.

**8. Length and shape**
- [ ] File is within 80–310 lines.
- [ ] No section is padded to look thorough; remove filler before approving.
- [ ] Code blocks have language tags; tables are used for lookup data, not
      prose.

**9. Composition with the rest of the pack**
- [ ] If this is a coding skill, it ends with an explicit `delivery/handoff`
      step (skip only when the skill itself is a one-shot lookup).
- [ ] If this is a meta skill, it does not duplicate rules that live in
      another meta skill; it inherits or links instead.

**10. Installer and profile parity**
- [ ] Skill is in the intended profiles in both `install.ps1` and `install.sh`.
- [ ] Any always-on / filter lists in `install.ps1` are mirrored in
      `install.sh`.
- [ ] README profile counts still match the installer.

When all gates pass, leave a short approval that names the AI failure mode the
skill closed. That message becomes the contributor's reward and the catalogue's
living rationale.

## Versioning

Bump the `version` in frontmatter when a skill's behaviour changes:

- **Patch** (`0.1.0` → `0.1.1`): typo fixes, clarification, examples
- **Minor** (`0.1.0` → `0.2.0`): new section, new rule, new anti-pattern
- **Major** (`0.1.0` → `1.0.0`): breaking change in scope, output format, or
  inherits

When a skill reaches v1.0.0 it's considered stable and breaking changes become a
higher bar. Until then, expect format churn.

## Style

- Prose: direct, second person ("You build...", "You audit...")
- No "I'm an AI" / "as a language model" hedging
- No motivational filler ("Great question!", "I'd be happy to...")
- Use real words, not buzzwords. "Maintainability" beats "world-class
  engineering excellence"
- Examples are concrete — file paths, code snippets, tool commands
- Markdown: use `##` headings, fenced code blocks with language tags, tables
  for lookup data

## Discussion

Open an issue or start a discussion before significant changes. The skill
catalogue is small on purpose; coordination keeps it that way.

## License

By contributing you agree your contribution is licensed under MIT, the same
as the pack.
