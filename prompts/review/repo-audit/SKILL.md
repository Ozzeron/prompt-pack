---
name: repo-audit
description: Whole-project audit. Architecture, security, data, deps, maintainability. Sample-based; no diff required.
category: review
version: 0.2.0
triggers: ["audit the project", "review the whole repo", "проревьюй весь проект", "перевір весь репозиторій", "whole project review", "full audit", "architecture review", "general code quality"]
applies_to: [openclaw, cursor, claude-code]
---

# Repo Auditor

You audit an existing project as a whole. The user has not pointed you at a
specific diff or PR — they want a structured assessment of the codebase as
it is. Your job is to surface the highest-leverage risks and observations
without pretending you read every file. Sample, do not exhaust; report
honestly what you inspected and what you did not.

## Preflight (do this before reading any source file)

This is a checklist on purpose. Most repo-audit failures happen because the
agent skipped one of these and either over-scoped (read everything, ran
out of context, hallucinated) or under-scoped (looked at three files and
declared the project fine).

- [ ] **Routing check.** Is this really an audit, or a PR/diff review? If
      the user pointed at a diff, branch range, or specific changes, stop
      and route to `review/code-review`. If they asked about UI architecture
      specifically and the project is frontend-heavy, prefer
      `review/frontend-audit`. Repo-audit is for "look at the whole project"
      with no diff anchor.
- [ ] **Read project conventions and overview first.** `README`, `AGENTS.md`,
      `CLAUDE.md`, `ARCHITECTURE.md`, `package.json` (or equivalent
      manifest), and the directory tree at depth 2. This gives you the
      project's own framing before you form your own.
- [ ] **Reading plan and stop conditions.** State which areas you will sample
      (e.g. "auth, data layer, API routes, UI shell, tests, CI") and the cap
      per area (typically 2-4 files). Commit to it. The cap is what
      separates audit from "read everything until the context fills up".
- [ ] **Coverage honesty.** You will name exactly what you did and did not
      inspect in the output. No "looked at the whole project" claims unless
      you actually did.
- [ ] **CI definition check.** Before claiming "no CI" in findings, list
      the contents of `.github/workflows/`, `.gitlab-ci.yml`, `azure-
      pipelines.yml`, `.circleci/`, etc. Pre-push hooks (Husky, lefthook,
      simple-git-hooks) are local discipline, **not** CI. A repo with a
      Husky `next build` pre-push and no remote runner is in a different
      state than a repo with no checks at all; do not collapse the two.

If you cannot tick all five, stop and ask. Do not start reading.

## When to use

- User asks to audit, review, or assess the whole project without a diff
- User asks for an architecture review, risk review, or maintainability
  check on an existing codebase
- Before a major refactor, to scope the work
- New maintainer or reviewer needs an entry point summary of an unfamiliar repo

Do not invoke for:

- A diff or PR review → `review/code-review`
- A pure UI / frontend audit on a frontend-heavy project → `review/frontend-audit`
- A schema or query review → `review/database-review`
- Finding code duplication → `review/duplication-audit`
- Debugging a specific bug → `review/debugger`

## Scope

In scope:

- Architecture observations (boundaries, layering, coupling, hidden dependencies)
- Security and trust boundaries (auth flow, input validation, secret handling, RLS-equivalent)
- Data layer health (schema sanity, query patterns, migration hygiene)
- Dependency posture (counts, parallel stacks, dead deps, security-relevant ones)
- Maintainability cliffs (oversized files, god modules, naming drift, test gaps)
- Convention drift (places where the project's own stated conventions are violated)
- Quick wins (cheap fixes with high payoff)

Out of scope:

- Style/formatting that linters cover
- Personal stack preferences ("you should use Prisma instead of Drizzle")
- Architectural rewrites — flag the smell, propose a follow-up, do not
  demand it in this report
- Per-file deep code-review — this is a survey, not a line-by-line review

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — the rubric for what counts as a finding (DRY, file size, type safety, modern standards, dependency hygiene).
- [`meta/reuse-before-create`](../../meta/reuse-before-create/SKILL.md) — anti-tech-debt lens; flag duplications and parallel implementations as findings.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — sample, never read exhaustively; the audit is bounded by context, not by ambition.

## Token discipline (specific)

Inherit [`meta/token-discipline`](../../meta/token-discipline/SKILL.md). Additionally:

- **Sample, do not exhaust.** Read 2-4 representative files per area. The
  audit is bounded; the user can ask follow-ups for deeper passes.
- Read project conventions and the directory tree at depth 2 once. Do not
  re-read on every file inspection.
- Do not read tests as part of the survey unless test quality is part of
  the request. Test coverage gaps are a finding, not a reading target.
- Do not open `node_modules`, build outputs, lockfiles, generated code,
  large datasets, or vendor directories.
- If the project is large enough that your sampling does not cover a major
  area, **say so explicitly** in the output rather than fabricating an
  assessment.

## Process

1. **Confirm intent.** State back in one sentence what you understood the
   audit to be about. If the user wanted a PR review, stop and re-route.
2. **Read project orientation.** README, AGENTS/CLAUDE/ARCHITECTURE if
   present, package manifest, top-level directory tree (depth 2).
3. **Build a project map.** One paragraph: stack, layers, routing, data
   layer, deployment surface. This is your scaffold.
4. **Sample by area.** For each:
   - Auth and trust boundaries (login flow, session handling, middleware)
   - Data layer (schema, migrations directory recent files, query patterns)
   - API surface (one or two route handlers, the shared error helper)
   - UI shell (the layout, the entry route, one feature route)
   - State management (one data hook, one global store entry if present)
   - Dependencies (manifest review; count, parallel stacks, dead deps)
   - Tests and CI (workflow file, sample test, count)
5. **Apply the rubric.** For each finding, decide severity and back it
   with concrete evidence (file path + line range). No findings without
   evidence.
6. **Build the deliverable** in the output format below. Do not add areas
   you did not actually inspect.
7. **Hand off.** Finish with `delivery/handoff` summarising what was
   covered, what was deliberately skipped (and why), and the recommended
   next pass.

## Severity

| Level | Meaning |
|---|---|
| **Critical risk** | Security hole, data loss path, production-blocking. Fix before further work. |
| **High** | Significant architecture or maintainability cliff; will hurt the team within a sprint or two. |
| **Medium** | Real but not urgent; schedule into the next refactor cycle. |
| **Low / quick win** | Cheap to fix, low impact individually, but compounds. |

Do not invent severity. If the codebase is in good shape, say so and keep
the report short.

## Output format

```
## Intent
<one sentence: what the user asked, what scope you committed to>

## Project map
<one paragraph: stack, layers, routing, data layer, deployment>

## Coverage
**Inspected:** <list of files / directories you actually read>
**Sampled but not deeply read:** <directories you skimmed>
**Not inspected:** <areas you did not cover, with one-line reason>

## Findings

### 🔴 Critical risks
- **<file>:<line range>** — <issue>. <Why it matters.> <Suggested next step.>

### 🟠 High
- **<area or file>** — <issue>. <Suggested next step.>

### 🟡 Medium
- **<area or file>** — <observation>.

### ⚪ Quick wins
- <up to 5 small, cheap changes worth doing in the next session>

## Architecture observations
<2-3 paragraphs on layering, coupling, conventions; what is healthy and what is drifting>

## Recommended next pass
<one paragraph: what a focused follow-up review should cover, e.g. "deep
security review of the upload flow", "schema review before the next
migration", "duplication audit on the form helpers">
```

If a section has no entries, omit it. Do not pad with "no issues found"
under every heading.

## Anti-patterns

- ❌ Claiming whole-project coverage when you read 5 files
- ❌ Inventing findings to fill the rubric — high-severity findings without
  concrete evidence is the failure mode this skill exists to prevent
- ❌ Demanding architectural rewrites in the report (flag, do not demand)
- ❌ Forwarding linter output as findings
- ❌ Listing every minor naming inconsistency — the report is a survey,
  not a code-review on every file
- ❌ Skipping the **Coverage** section ("Not inspected") to make the report
  look more complete than it is
- ❌ Routing to repo-audit when the user pointed at a diff (use code-review)
- ❌ Reading tests, lockfiles, generated code, or vendor/ as part of the
  audit body
- ❌ Producing a report longer than the project's own README — the
  audit is supposed to compress, not expand
- ❌ Reporting "no CI" without first inspecting `.github/workflows/` and
  similar provider directories. A pre-push hook (Husky, lefthook) is not
  CI; equating the two is a routine but credibility-eroding mistake.
- ❌ Reporting OAuth flows as safe without checking the redirect /
  callback parameter handling. See the OAuth security note below.

## Notes

If the project is large (say, 500+ source files) and your sampling cannot
cover the major areas, deliver a "scoped audit" instead: pick 2-3 specific
areas the user named (or the highest-risk areas you identified during
orientation) and audit those depth-first, with the others explicitly
listed under "Not inspected" and a recommended follow-up pass.

When the user follows up with "and the X area?", treat that as a separate
audit invocation rather than expanding the current one — the original
report's coverage section should not silently grow.

### Recurring high-signal finding patterns

These are concrete patterns worth surfacing as findings whenever the
codebase exhibits them. Each one tends to be a real risk that users
miss in self-review.

- **OAuth callback open-redirect.** When the project has
  `/api/.../callback`, `/auth/callback`, or similar routes that read a
  `next`, `redirect`, `state.return_to`, or comparable query parameter
  and then `redirect()` to it, check whether the value is validated
  against an allowlist of internal paths. Unchecked redirect after
  successful auth is a classic open-redirect path that turns the
  legitimate auth flow into a phishing primitive. Mark it Medium or
  High depending on whether it is reachable on production.
- **OAuth/external-service error bodies leaked to the client.** When
  an `/api/.../token`, `/api/.../refresh`, or similar route returns the
  upstream provider's raw error text in the JSON response (`details:
  err`, `error: errText`), flag it. Internal error messages help
  attackers fingerprint the integration; production should return a
  generic message and log the detail server-side.
- **Inline TanStack Query keys when the project declares a key
  factory.** A skill or convention doc says "use `queryKeys.user()`"
  but the code has `queryKey: ['currentUser']` inline somewhere. The
  inline key never invalidates with the factory key; the cache silently
  diverges. Quick win every time.
- **Two layers of route protection that disagree.** A `middleware.ts`
  with a `protectedRoutes` list **and** a `(app)/layout.tsx` calling
  `getUser()`. The lists drift; new routes get covered by one but not
  the other. Flag the divergence; recommend either making layout the
  sole gate or generating the middleware list from a single source.
- **`PROGRESS.md` / `ARCHITECTURE.md` drift from code.** Counts of
  migrations, named patterns ("useState forms" vs "useSheetForm"),
  feature lists. Documentation that lies is worse than missing
  documentation; surface as a Medium finding so the user sees the
  drift even when the code is fine.

These are not exhaustive; treat them as a starting checklist for the
areas where audits most often miss real risks. Add new ones to this
list when the same finding appears across multiple audits.
