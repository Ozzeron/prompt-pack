---
name: refactor-planner
description: Plan a safe step-by-step refactor. Expand-then-contract; every step ships green; rollback per step.
category: architecture
version: 0.1.0
triggers: ["refactor", "migrate", "restructure", "split this file", "rewrite", "untangle"]
applies_to: [openclaw, cursor, claude-code]
---

# Refactor Planner

You take a "we should refactor X" request and turn it into a sequence of small, safe,
shippable steps. The default for refactors is **expand-then-contract**, the same pattern
that keeps database migrations safe: introduce the new shape alongside the old, switch
consumers piece by piece, remove the old shape only after everything is on the new one.

The most common refactor failure isn't getting the design wrong — it's the all-at-once
rewrite that breaks 12 things and gets reverted. This skill exists to prevent that.

## When to use

- "Split this 1,200-line file into modules"
- "Move from React Context to Zustand" (or any library swap)
- "Rename / restructure this module"
- "Extract this duplicated logic"
- "Collapse these three near-duplicate components"
- "Migrate from REST to tRPC" / "from Pages Router to App Router" / similar
- After `review/frontend-audit` or `review/database-review` produces findings that need
  multi-step execution

Do not invoke for:
- One-line edits or trivial renames (just do them)
- Greenfield work (use `architecture/frontend-feature` / `architecture/backend-api`)
- The actual code-writing — this skill produces the plan, the architecture skills execute

## Scope

In scope:
- Step-by-step plan with each step independently shippable
- Risk and rollback strategy per step
- Order of operations to keep the codebase green throughout
- Estimated size of each step (S/M/L)
- Dependencies between steps
- Tests / verification needed at each step
- What stays in scope vs explicit out-of-scope

Out of scope:
- Executing the plan — refactor-planner produces the plan, not the diff
- Architectural redesign that hasn't been agreed on — confirm the *destination* with the
  user before planning the journey
- Renames / cleanups outside the stated scope — propose as follow-ups, don't bundle

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — DRY, file size, single responsibility shape *what* is being refactored toward.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — read the target area, not the whole repo.
## Token discipline (specific)

- Read the **specific area being refactored**, not the whole codebase.
- Read 1–2 sibling modules / patterns to understand what "good" looks like in this project.
- Read the project's existing test setup once — knowing what tests cover the area
  determines how aggressive each step can be.
- Skip historical commits unless the refactor is explicitly to undo a past change.
- Do NOT read every consumer of a function before planning — list them via grep, sample
  the most representative ones, plan the migration shape.

## The cardinal rule: every step ships green

A step is **shippable** when:
- The codebase compiles / typechecks
- Tests pass
- The application works as before from a user's perspective
- It can be merged and deployed without breaking anything

A plan that has a "WIP" step in the middle has failed. If you can't see how to keep the
build green, the step is too big — split it.

## The expand-then-contract pattern

Borrowed from database migration discipline, applied to code:

```
1. EXPAND   — introduce the new shape alongside the old
2. MIGRATE  — move consumers one by one, in arbitrary order
3. CONTRACT — once nothing references the old shape, remove it
```

Each phase is its own ship. The old shape stays working until the very end.

### Examples

**Renaming a function `getUser` → `fetchUser`:**
1. Add `fetchUser` as a re-export of `getUser`. Both work. Ship.
2. Update consumers in batches — by feature, by file, by author. Ship each batch.
3. Once `getUser` has zero references, remove it. Ship.

**Splitting a 1,200-line component:**
1. Identify natural sub-components (hero, table, sidebar). Add their files alongside the
   monolith, exporting nothing yet. Ship (no behaviour change).
2. Move one section into its sub-component, import it back into the monolith. Ship.
3. Repeat per section.
4. The monolith is now a thin shell composing sub-components. Inline-or-delete it.

**Library swap (Context → Zustand):**
1. Add Zustand store with the same shape as the Context value. Ship.
2. Add a compatibility hook that reads from either: Zustand if hydrated, Context otherwise.
   Switch one consumer to the new hook. Ship.
3. Migrate consumers one at a time. Ship each.
4. Remove the Context provider once unused. Ship.

**Folder restructure:**
1. Create the new structure. Add re-exports from old paths to new locations. Ship.
2. Move imports in batches. Ship each.
3. Remove old re-exports. Ship.

## Process

1. **Confirm the destination.** What does the codebase look like *after* the refactor?
   Sketch it briefly. If the user hasn't decided, stop and ask. The destination is not
   optional — you can't plan a journey without one.
2. **Audit the starting state.**
   - What files / modules are involved?
   - How many consumers does the thing-being-changed have? Use grep to count.
   - What tests exist for this area? (Determines how confidently each step can be shipped.)
3. **Choose the pattern.** Default: expand-then-contract. Use a different pattern only
   if you can justify why expand-then-contract doesn't apply.
4. **Decompose into steps.** Each step:
   - Has a one-line goal
   - Is shippable on its own
   - Has a rollback ("revert this commit" usually, but state it)
   - Has a verification (tests run? smoke flow? manual check?)
5. **Estimate size.** Per step: **S** (≤1 hour), **M** (half day), **L** (1+ day).
   If a step is **L**, try to split it further.
6. **Identify dependencies.** Some steps must precede others; some are parallelisable.
7. **Define out-of-scope.** What's tempting to fix along the way but stays out. List
   them — they become follow-up tickets, not silent additions.
8. **Hand off the plan** for review. Once approved, execution goes to whichever
   architecture skill matches (`backend-api`, `frontend-feature`, `database-migrations`).

## Step template

```
### Step N: <one-line goal>

**Phase:** EXPAND / MIGRATE / CONTRACT (or other, justified)
**Size:** S / M / L
**Depends on:** Step N-1 (if any)

**What changes:**
- <File / module> — <one-line change>

**Verification:**
- <Test command, smoke check, or "verify this manually">

**Rollback:**
- <Revert this commit / feature flag toggle / etc>

**Why this is safe to ship alone:**
- <One sentence: nothing user-visible changes / both shapes coexist / etc>
```

## Output format

```
## Goal
<One sentence: what the codebase looks like after this lands>

## Why now
<Trigger: audit finding, repeated bug, planned feature blocked, etc>

## Starting state
- Files involved: <list>
- Consumers of changing code: <count + how to find them>
- Test coverage of area: <good / spotty / none>

## Pattern
<Expand-then-contract / other, with one-line justification>

## Steps

### Step 1: ...
### Step 2: ...
...

## Out of scope (intentional)
- <Tempting cleanup that stays out, with reason>
- <Adjacent refactor for a separate plan>

## Risks
- <What could go wrong, even with the staged plan>
- <What the steps don't protect against>

## Open questions
- <Things blocking finalization>
```

## Sizing intuition

Use these as calibration, not law:

| Refactor | Realistic step count | Total effort |
|---|---|---|
| Rename a function (≤50 consumers) | 3 (expand / migrate / contract) | ~half day |
| Split a 1,000-line file into 5 modules | 5–7 | 1–2 days |
| Library swap (state, forms, fetching) | 6–10 | 3–5 days |
| Move from REST to tRPC | 8–15 | 1–2 weeks |
| Pages Router → App Router (small app) | 10–20 | 1–3 weeks |

If your plan has 3 steps for a library swap, you're cheating the steps. If your plan has
20 steps for a function rename, you're over-engineering.

## Anti-patterns

- ❌ A "WIP" step that doesn't compile or doesn't work
- ❌ "Big-bang" refactor in one diff — that's a rewrite, not a refactor
- ❌ Bundling unrelated cleanups into the plan ("while we're here...")
- ❌ Skipping the destination — "let's just start cleaning this up" without a target
- ❌ A plan with no rollback strategy per step
- ❌ Steps without verification — "run tests" doesn't count if there are no tests
- ❌ Renaming + behaviour change in the same step (do them separately so blame is clean)
- ❌ Migrating consumers in a single step when there are >10 of them
- ❌ Removing the old shape before all consumers are gone — guaranteed regression
- ❌ Treating the planner as the executor — this skill outputs the plan, not the diff
- ❌ Estimating L for everything because "refactors are hard" — split the L into S/M
- ❌ "Refactor" that's actually a redesign without product-side discussion

## Notes

When the destination is fuzzy ("just clean this up"), refuse to plan until it's
specific. "Move all data fetching to a hooks layer" is plannable; "make this less of a
mess" isn't.

When tests are sparse, the plan must add **observability before changing behaviour**.
That might be its own step early in the plan: add tests / add logs / add a feature flag,
*then* start the refactor. Refactors without verification are wishes, not plans.

When the refactor is risky enough to need a feature flag, say so explicitly. Some
refactors are best done behind a flag with the new path running for a subset of users
before flipping the default.

For database refactors, defer to [`architecture/database-migrations`](../database-migrations/SKILL.md)
— it has the lock-aware, expand-then-contract patterns specific to schema work. This skill
covers code-side; that one covers DB-side. Most real refactors involve both.
