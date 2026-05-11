---
name: engineering-principles
description: Cross-cutting engineering standards every coding skill inherits. DRY, modular, type-safe, maintainable, modern.
category: meta
version: 0.1.0
triggers: [inherit-only]
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

Delegated to the dedicated meta skill: **[`meta/reuse-before-create`](../reuse-before-create/SKILL.md)**.

That skill is the single source of truth for the reuse-vs-create decision: the strict
ordering (reuse → extend → compose → extract → create new), the mandatory one-line
justification when creating, the per-artifact-type search strategies, and the
"don't trust names alone" rule.

Do not duplicate that logic in this skill or any other. Inherit it, follow it.

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

New dependencies are the most common form of silent technical debt: each one is a
perpetual maintenance, security, and bundle-size cost paid by everyone, often to save
a few lines once.

Before `npm install <anything>`:

- **Search the existing dependency tree first.** Run `cat package.json` (or equivalent)
  and check whether a current dep already covers the need. Common false adds: a date
  library when `date-fns` / `dayjs` / `luxon` is already there; a fetch wrapper when
  `axios` / `ky` is present; `lodash.debounce` when `lodash` itself is in deps; a UUID
  lib when `crypto.randomUUID()` already works in target runtimes.
- **Try 5 lines first.** If the task is `debounce`, `groupBy`, `chunk`, `formatBytes`,
  `slugify`, `clamp`, `range`, `sleep`, or similar single-purpose helpers, write it
  inline. These are not dependency-worthy.
- **Justify in writing.** A new dep is allowed when it crosses one of these bars:
  cryptographic correctness (hashing, signing, JWT), parsing complexity (CSV, XML, ICS,
  YAML), browser/runtime compatibility (date-fns over hand-rolling timezone logic),
  large surface (form library, query client, ORM). The justification belongs in the
  PR description / handoff, one sentence, naming the alternative considered.
- **Match the project, do not import parallel stacks.** If the project uses Zod, do
  not add Yup. If it uses TanStack Query, do not add SWR for one component. Parallel
  stacks are how monorepos rot.
- **Check size and freshness.** Use `npm view <pkg> dist.unpackedSize`, look at last
  publish date, and look at open critical issues. Dead packages (no release in 18+
  months on a security-relevant area) are a no.
- **Lockfile hygiene.** Pin the version, update the lockfile, do not silently bump
  unrelated transitive deps in the same PR.

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

## 12. Workspace hygiene gate

After file-generating work, run a workspace hygiene check before the final response:
classify new and untracked artifacts, remove only clearly safe self-created temporary
files, and list uncertain cleanup candidates. See [`meta/artifact-hygiene`](../artifact-hygiene/SKILL.md)
for full rules. Never use broad destructive commands (`rm -rf`, glob deletes without
scoped paths) as part of cleanup.

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
