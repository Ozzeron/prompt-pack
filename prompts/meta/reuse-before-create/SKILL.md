---
name: reuse-before-create
description: DRY discipline core. Before creating anything new, find what already exists. Every coding skill inherits this.
category: meta
version: 0.1.0
triggers: ["writing code", "adding component", "adding util", "adding type", "creating file", "new helper", "new hook"]
applies_to: [openclaw, cursor, claude-code, generic]
---

# Reuse Before Create

The single most consistent way AI coding agents degrade a codebase is by creating new
artifacts when existing ones would do. New components instead of props. New utilities
instead of imports. New types instead of references. The codebase doubles in volume,
quality halves, and every requirement change now means N edits instead of one.

This skill is the central rule for that. Every coding skill in this pack inherits it. It
is not aspirational; it is a precondition for any code-creating action.

## When to use

Always, whenever you are about to write a new component, function, hook, util, type,
constant, schema, configuration, or dependency. This is a precondition step, not an
optional review.

## The rule

**Before writing anything new, search for what already exists. Reuse first; create last.**

The order of preference is strict and non-negotiable:

1. **Reuse as-is** — existing artifact fits, import and use
2. **Extend** — add a prop, option, generic, or branch to existing artifact
3. **Compose** — combine existing artifacts into a new shape without rewriting them
4. **Extract** — pull a shared core out of two near-duplicates; both use the new core
5. **Create new** — only when none of the above apply

Each step further down costs more — both in code volume and in long-term maintenance.
Skipping straight to "create new" without proving the prior steps don't apply is the
default failure mode this skill prevents.

## Justification is not optional

When you do create something new, **a one-line justification is mandatory**, not a
nice-to-have. It belongs in the commit message, the PR description, the handoff, or as
an inline comment near the new artifact. Format:

> *"Created `formatDateTz`: no existing util handles ISO date with timezone offset; the
> project's `formatDate` strips the zone."*

This rule applies to every kind of new artifact: component, hook, util, type, constant,
schema, dependency, file, folder.

If you can't write the justification in one sentence, you haven't searched hard enough.
Go back to step 1.

## How to actually search

The most common excuse for skipping reuse is "I looked and didn't find it." That usually
means the search was shallow. Effective searches:

### By artifact type

| Looking for | Search strategy |
|---|---|
| **UI component** | grep `<ComponentName`, check `components/`, `components/ui/`, `shared/`, `design-system/` |
| **Hook** | grep `use*` prefix, check `hooks/`, `lib/hooks/` |
| **Utility** | grep verb prefix (`format*`, `parse*`, `validate*`, `is*`, `to*`), check `lib/`, `utils/`, `helpers/` |
| **Type / interface** | grep `interface ` or `type ` for the shape, check `types.ts`, `schema.ts`, `models.ts` |
| **Constant / enum** | grep the value or its semantic name, check `constants.ts`, `config.ts` |
| **Schema / validator** | grep `z.object`, `Yup.object`, `pydantic`, check `schema.ts`, `validation.ts` |
| **API endpoint / route** | grep the path, check `routes/`, `api/`, `pages/api/`, `app/api/` |
| **Data hook / query** | grep the resource name, check `api/`, `data/`, `queries/`, `hooks/` |
| **Style class / token** | grep the class string or hex value, check `theme.ts`, `tokens.ts`, `tailwind.config` |

### Don't trust names alone

Names lie. The codebase may have a `formatDate` that strips timezones, a `useUser` that
fetches a different user shape than you need, or a `Button` that secretly hardcodes a
variant.

Before reusing or extending an existing artifact, **grep for its imports and call sites**
to confirm what it actually does. This is especially important in older or AI-touched
codebases where naming has drifted from behaviour.

```bash
# Before reusing useUser, see how it's actually called
grep -rn "useUser" --include="*.ts" --include="*.tsx"
```

### Sample, then read

Don't open every match. Sample 1–2 representative call sites to confirm behaviour, then
decide. If the sample disagrees with the name or doc, surface that as a finding (the
existing artifact is misnamed) — but it doesn't change your decision: still reuse if it
fits the actual behaviour you need.

## Decision flow

```
You're about to write something new.
  │
  ├─ Search for existing equivalent (use the table above)
  │
  ├─ Found something with the right behaviour?
  │     ├─ YES → IMPORT IT. Done.
  │     └─ NO → continue
  │
  ├─ Found something close (same shape, missing one option)?
  │     ├─ YES → EXTEND IT (add prop/option/generic). Done.
  │     └─ NO → continue
  │
  ├─ Can you build it from existing pieces (composition)?
  │     ├─ YES → COMPOSE. Done.
  │     └─ NO → continue
  │
  ├─ Are there 2+ near-duplicates of what you need that you could unify?
  │     ├─ YES → EXTRACT shared core, migrate both. Done.
  │     └─ NO → continue
  │
  └─ Create new. Write the one-line justification.
```

## Anti-patterns

- ❌ "Quick" duplicate of an existing component with one minor visual tweak — pass a prop
- ❌ Three near-identical formatter functions for dates, money, percentages — one with options
- ❌ Copying a hook into a new feature folder — move it to `hooks/` and import
- ❌ Re-declaring the same TypeScript shape inline in 5 places — define once, import
- ❌ Wrapping a library primitive only to rename props — fight the urge
- ❌ "I didn't find anything" without showing what you searched for — the search was shallow
- ❌ Creating new files inside a feature folder for things that should be shared
- ❌ Adding a new dependency to "save 10 lines" of code already in the project's utilities
- ❌ Justifying creation with "the existing one wasn't quite right" without saying what wasn't right
- ❌ Premature abstraction: extracting a "generic" version on the first occurrence — wait for the
  second instance, extract on the third (rule of three)
- ❌ Creating a new abstraction layer ("FormFactory", "ComponentBuilder") instead of extending
  existing primitives

## When NOT to reuse

Reuse has limits. Don't force it when:

- **The shapes are similar but the contracts differ.** Two functions named `formatPrice`
  that look the same but one rounds and the other floors are not duplicates — they're a
  naming bug. Don't merge them; rename them.
- **Soon-to-diverge code.** If you know one variant will get unique requirements next
  sprint, premature unification creates a worse problem.
- **Cross-domain coupling.** Reusing a `User` type from the auth module in the billing
  module's invoice flow couples them. Define a billing-specific type that takes what it
  needs from the user.
- **Library primitive does it differently.** Don't fork a shadcn/Radix/MUI component to
  fix a behaviour you don't like — usually the library is right and you've misunderstood.

## What this skill does NOT do

- This skill prevents creation when reuse is possible. It does not perform refactors.
- It does not audit existing duplication — that's [`review/duplication-audit`](../../review/duplication-audit/SKILL.md).
- It does not enforce style or design — that's the architecture skills.
- It does not produce output directly. You internalise the rule and apply it whenever a
  parent skill triggers code creation.

## Notes

When the parent skill (e.g. `architecture/frontend-feature`) provides a "file plan", every
"new" entry in the plan must have its one-line justification attached. If the plan has
more than 1–2 "new" entries, that's the signal to go back and search harder before
proceeding.

For codebases where the existing artifact you want to reuse is genuinely bad — not just
unfamiliar — the right response is to **flag it for refactor** (`architecture/refactor-planner`)
and reuse it anyway in the current task. Don't compound the problem by adding a parallel
implementation.

When in doubt: **the second time you write the same thing, extract it; the third time, you've
already lost.**
