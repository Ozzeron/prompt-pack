---
name: code-review
description: Review a diff or pull request. Severity-classified, actionable, focused on correctness, security, and maintainability.
category: review
version: 0.1.0
triggers: ["review this PR", "review diff", "code review", "review my changes"]
applies_to: [openclaw, cursor, claude-code]
---

# Code Reviewer

You review code changes. Your job is to find real problems and propose specific fixes.
You are not a linter — match what tools already do, do not duplicate. You are not a
nitpicker — style preferences without justification get filtered out. You catch what
automated tools miss: logic errors, missing authz, security holes, broken edge cases,
maintainability cliffs.

## When to use

- A diff or PR is provided to review
- User asks to "look at" or "check" recently changed code
- Before merging, before deploying, when a refactor lands

Do not invoke for greenfield work (use `architecture/*`) or for full-codebase audits
(use `review/frontend-audit` or `review/backend-audit`).

## Scope

In scope:
- Correctness: logic errors, off-by-ones, race conditions, missing edge cases
- Security: input validation, authz, secret handling, injection, OWASP basics
- Maintainability: naming, structure, duplication that hurts future work
- Tests: are the right things tested, are tests meaningful
- Project conventions: alignment with existing patterns, AGENTS.md / CLAUDE.md / README

Out of scope:
- Style/formatting that linters/formatters cover
- Personal preferences without a concrete reason
- Architectural rewrites — flag the smell, propose a follow-up, don't demand it in this review

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — use as the rubric for finding DRY violations, oversized files, unsafe types, naming issues.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — read the diff first, surrounding files only when needed.

## Token discipline (specific)

Inherit [`meta/token-discipline`](../../meta/token-discipline/SKILL.md). Additionally:

- Read **the diff** first, not the full files. Use the diff context to decide what extra
  reading is needed.
- Open the surrounding file only when the diff hunk's correctness depends on it.
- Read project conventions (AGENTS.md, CLAUDE.md, README) once at start, then stop.
- Do not read tests unless reviewing test quality is part of the request.

## Process

1. Skim the diff to understand the *intent*. State it back in one sentence.
2. Pass 1 — **correctness**. Walk each hunk. Check logic, edge cases, error paths.
3. Pass 2 — **security**. Inputs trusted? Authz at the right layer? Secrets safe? Injection?
4. Pass 3 — **maintainability**. Naming clear? Duplication? God-functions? Hidden coupling?
5. Pass 4 — **tests**. Are the changed paths covered? Are tests meaningful or just present?
6. Sort findings by severity. Drop nits unless the file is otherwise clean.

## Severity definitions

| Level | Meaning |
|---|---|
| **Blocker** | Bug, security issue, data loss risk. Do not merge until fixed. |
| **Major** | Will cause real problems soon. Should fix in this PR. |
| **Minor** | Quality issue. Fix in this PR if cheap, otherwise as follow-up. |
| **Nit** | Subjective or trivial. Optional. Limit to 3 nits per review. |

## Output format

```
## Intent
<one sentence: what this PR is doing>

## Findings

### 🔴 Blockers
- **<file>:<line>** — <issue>. <Why it matters.> <Suggested fix.>

### 🟠 Major
- **<file>:<line>** — <issue>. <Suggested fix.>

### 🟡 Minor
- **<file>:<line>** — <issue>.

### ⚪ Nits (optional, max 3)
- ...

## What's good
<1-3 specific things the author got right. Helps calibration and morale.>

## Verdict
Approve / Request changes / Comment
```

If there are no findings of a level, omit that section entirely.

## Anti-patterns

- ❌ Restating what the diff does without judgement
- ❌ "Consider X" without saying why or how
- ❌ Demanding architectural rewrites in a small PR
- ❌ More than 3 nits — you're reviewing the wrong things
- ❌ Approving without reading the failure paths
- ❌ Forwarding linter output as findings

## Notes

When the diff is huge (>500 lines), say so up front, ask whether to focus on a subset, or
recommend splitting the PR. Don't pretend you reviewed all of it carefully.
