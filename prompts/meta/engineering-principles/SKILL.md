---
name: engineering-principles
description: Cross-cutting engineering standards every coding skill inherits. DRY, modular, type-safe, maintainable, modern.
category: meta
version: 0.1.0
triggers: [always, "writing code", "modifying code"]
applies_to: [openclaw, cursor, claude-code, generic]
---

# Engineering Principles

The non-negotiable rules every coding skill in this pack must follow. AI agents tend to
emit code as if there is no tomorrow: duplicate components, monolithic files, fresh
abstractions instead of reuse, no types, no structure. This document exists to stop that.

Every architecture, review, and interface skill inherits these rules. Specific roles add
detail on top, but never relax them.

## When to use

Always, whenever you write or modify production code. This is a cross-cutting concern.

## 1. DRY — reuse before creating

**Before writing a new component, function, hook, util, type, or constant, search for
something that already does the job.**

The order of preference is strict:

1. **Reuse as-is** — if existing code fits, use it
2. **Extend** — add a prop, an option, or a generic parameter to existing code
3. **Compose** — combine existing pieces into a new shape without rewriting them
4. **Extract** — pull a shared core out of two near-duplicates and have both use it
5. **Create new** — only when none of the above apply

When you do create something new, **a one-line justification is required** — not optional.
It goes into the handoff or PR description, not buried as a comment. Example:
*"Created `formatDateTz`: no existing util handles ISO date with timezone offset; the
project's `formatDate` strips the zone."*

This rule applies to every kind of new artifact: component, hook, util, type, constant,
dependency. If you can't write a one-line justification, you haven't searched hard enough.

### How to actually search

- Grep for the type of thing you need: component name patterns, hook prefixes (`use*`),
  utility verbs (`format*`, `parse*`, `validate*`)
- Read the project's `components/`, `lib/`, `utils/`, `hooks/`, `shared/` directories' index
- Check `types.ts`, `schema.ts`, `constants.ts` for existing definitions
- For UI: check the design system / shadcn / library primitives before building from scratch
- **Don't trust names alone.** Before reusing or extending an existing component or
  function, grep for its imports / call sites to confirm what it actually does. Names lie;
  usage doesn't. This is especially important in older or AI-touched codebases where
  naming has drifted from behaviour.

### DRY anti-patterns

- ❌ "Quick" duplicate of an existing component with one minor visual tweak — pass a prop instead
- ❌ Three near-identical formatter functions for dates, money, percentages — one with options
- ❌ Copying a hook into a new feature folder — move it to `hooks/` and import
- ❌ Re-declaring the same TypeScript shape inline in 5 places — define once, import
- ❌ Wrapping a library primitive only to rename props — fight the urge

## 2. File and function size

Code is read more than written. Optimise for the next reader.

| Unit | Soft limit | Hard limit |
|---|---|---|
| Function | 40 lines | 80 lines |
| React component | 150 lines | 250 lines |
| File | 250 lines | 400 lines |
| Class | 200 lines | 350 lines |

When you approach the soft limit, **split**. Hitting the hard limit without splitting is a
code smell to flag in review.

Splitting strategies:
- Extract sub-components for distinct UI regions
- Pull pure helpers into the same folder, import locally
- Move types to a `types.ts` next to the file
- Group related functions into a class or module if they share state

## 3. Single responsibility

A function, component, hook, or module does **one thing**. If you can't describe what it
does in a single sentence without "and", split it.

Common violations:
- A component that fetches data, renders UI, and handles navigation — split into hook + UI
- A util that validates AND transforms — make two functions
- A "manager" class with 12 methods — likely 3 modules pretending to be one

## 4. Type safety (when the language supports it)

For TypeScript, Python (with type hints), Rust, Go, Kotlin, Swift, and similar:

- **No `any`** in TypeScript without an inline comment explaining why and what's safer
- **No untyped function signatures** — params and return are annotated
- **Validate at trust boundaries** — user input, API responses, file imports, env vars.
  Use Zod, pydantic, or equivalent. Don't trust the compiler past the boundary.
- **One source of truth for shared shapes** — derive frontend types from API schema or vice
  versa, don't maintain two parallel definitions
- **Discriminated unions over flag soup** — `{ kind: 'loading' } | { kind: 'error', err } | { kind: 'ok', data }`
  beats `{ loading, error, data }`

For dynamically typed languages without types, the discipline shifts to:
- explicit input validation at function entry
- tests that codify the expected shape

## 5. Naming

- Names answer the question "what is this for", not "what is this technically"
- Boolean variables and props start with `is`, `has`, `can`, `should`
- Functions are verbs (`fetchUser`, `validateEmail`); values are nouns (`user`, `email`)
- No abbreviations except universally understood ones (`id`, `url`, `db`, `api`)
- Prefer specific over generic: `userPreferences` not `data`, `errorBanner` not `component`
- Match the project's existing convention even if you'd choose differently

## 6. Imports and dependencies

- Don't add a dependency when 5 lines of code solve it
- Don't add a dependency when an existing one already does the job
- New dependencies need a one-line justification in the PR/handoff
- Prefer the project's existing tools (state library, form library, validator) over
  introducing parallel ones

## 7. State management

- Local state by default — lift only when needed by a sibling
- Server state stays in the data layer (React Query, SWR, equivalent), don't duplicate into local state
- URL state for things that should survive refresh and be shareable (filters, tabs, ids)
- Global state only when truly cross-cutting (auth, theme); not for "I don't want to drill"
- Derived state is computed, not stored

## 8. Error handling

- Never swallow errors silently. Either handle or propagate with context
- Errors at trust boundaries become user-facing messages — generic outward, detailed in logs
- Don't `try/except` whole functions to "avoid crashes" — that hides bugs
- Use `Result`/discriminated unions where the language idioms support it; otherwise typed exceptions

## 9. Comments and self-documenting code

- Code should explain *what* by its structure
- Comments explain *why*: business rules, non-obvious constraints, references to tickets
- Stale comments are worse than no comments — delete or update
- TODOs include a name and a date, otherwise they're decorative

## 10. Modern standards

Use the language and framework features that exist *today*, not the ones from 5 years ago.

- **TypeScript:** prefer `unknown` over `any`, satisfy operator, const assertions, template literal types
- **JavaScript/TS:** ESM, top-level await where supported, optional chaining, nullish coalescing,
  no `var`, no `function` declarations for callbacks
- **React:** function components only, no class components for new code; React 19 features
  (Actions, `use`, `useOptimistic`) where the project supports them; Server Components by default
  in Next.js App Router unless interactivity is needed
- **Python:** type hints, `match` statements where they fit, `pathlib` over `os.path`,
  `dataclass`/`pydantic` over dicts for structured data
- **CSS:** modern selectors (`:has`, `:is`, `:where`), container queries where supported,
  logical properties; design tokens not magic values
- **Forms:** validated schemas (Zod, pydantic), not ad-hoc `if` chains
- **Async:** `async/await`, not callback chains; `AbortController` for cancellation
- **Tests:** colocated with code or in mirrored structure; no copy-pasted setup —
  use fixtures/factories

When working in a project that hasn't adopted a modern feature yet, **don't unilaterally
introduce it** — match the project's baseline. Flag the gap in the handoff if it's
worth raising.

## 11. Maintainability checks (apply mentally before finishing)

- Will the next person understand this in 5 minutes from filename + signature?
- If a requirement changes, how many places do I edit?
- Could this be tested? Is it tested?
- Is anything in this file unrelated to its filename?
- Did I add code that's already in the codebase under a different name?

If any answer is uncomfortable, fix it before handing off.

## Anti-patterns summary

- ❌ New component when a prop on the existing one would do
- ❌ Files over 400 lines that "make sense as one file"
- ❌ `any` in TypeScript "for now"
- ❌ Generic names like `Helper`, `Manager`, `Util`, `data`
- ❌ Duplicated formatters/validators per feature folder
- ❌ A hook that does fetching, transformation, and routing in one
- ❌ State libraries layered on top of state libraries
- ❌ Comments that paraphrase the next line
- ❌ Adding a dependency to "save 10 lines"
- ❌ Quietly upgrading to a fancy new pattern the project doesn't use elsewhere

## Output expectation

You do not produce output for this skill directly. You internalise the rules and apply
them whenever you write code under any other skill in this pack.
