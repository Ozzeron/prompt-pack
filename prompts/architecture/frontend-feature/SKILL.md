---
name: frontend-feature
description: "Builds a client-side feature end to end: routing, data fetching, state, forms and validation, types, and every UI state (loading, empty, error, success), reusing what the repo already has. Use when asked to add a page, route, screen, dashboard, or CRUD flow that spans routing plus data plus UI. Not for visual-only design (ui-designer), single-component edits, backend or schema work, or auditing existing code (frontend-audit)."
license: MIT
metadata:
  pp-category: architecture
  pp-version: "0.2.0"
  pp-activation: native
  pp-surfaces: "openclaw, cursor, claude-code"
---

# Frontend Feature Builder

You build a frontend feature end-to-end: routing, data fetching, state, forms, validation,
UI, error handling, tests. The work spans multiple files and touches several layers, so
**discipline matters more than ambition**: match the project's existing architecture, reuse
its primitives, and don't introduce parallel patterns.

## When to use

- New page, route, or self-contained feature on the client
- "Add CRUD for X", "build settings for Y", "implement the dashboard for Z"
- Cross-layer work: routing + data + UI together

Do not invoke for:
- Pure visual design without data integration (use `interface/ui-designer`)
- Single-component changes (just edit it)
- Backend or DB work (use `architecture/backend-api`, `architecture/database-schema`)
- Auditing existing code (use `review/frontend-audit`)

## Scope

In scope:
- Routing / route definition
- Data fetching, mutations, optimistic updates, cache invalidation
- Local + URL + server state coordination
- Forms: schema, validation, submission, errors
- UI: layout, components, states (delegated to `ui-designer`)
- Types end-to-end (API contract → form → render)
- Loading, empty, error, success paths
- Tests for the feature's behaviour, not its implementation details

Out of scope:
- API contract design — assume one exists or specify what's needed and stop
- Database changes — call out the requirement, don't author the migration
- Cross-cutting infrastructure (auth, theming, analytics) — use what exists, flag gaps

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — file size, type safety, naming, modern standards.
- [`meta/reuse-before-create`](../../meta/reuse-before-create/SKILL.md) — the DRY decision flow; every "new" entry in your file plan must satisfy this skill's checks.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — sample, don't read everything.
- [`interface/ui-designer`](../../interface/ui-designer/SKILL.md) — for the UI portion: creativity calibration, restraint, visual consistency.
## Token discipline (specific)

- Read 1–2 sibling features to learn the project's data + state + form patterns. **If they
  conflict, read a canonical one or `AGENTS.md`/`README` before deciding.**
- Read the relevant API client / data layer entry point once.
- Read the project's form library setup (React Hook Form / Formik / vee-validate / Vuelidate / SvelteKit form actions / Angular forms / custom) once.
- Read the design system primitives index once (delegated to `ui-designer`).
- Do NOT read the entire `pages/` or `app/` directory.
- Do NOT read tests of unrelated features.

## Framework vocabulary

Translate these concepts through the project's actual framework. React is one example, not the default.

| Concept | React / Next | Vue / Nuxt | Svelte / SvelteKit | Angular |
|---------|--------------|------------|--------------------|---------|
| Component | `function Comp()` | SFC `<script setup>` | `.svelte` file | `@Component` class |
| Reactivity | `useState`, `useReducer` | `ref`, `reactive`, `computed` | `$state`, `$derived` | signals, `BehaviorSubject` |
| Side effects | `useEffect` | `watch`, `watchEffect` | `$effect` | `ngOnInit`, subscriptions |
| Routing | Next App Router, React Router | `vue-router`, Nuxt pages | SvelteKit routes | `RouterModule` |
| Global state | Context, Zustand, Jotai | Pinia, Vuex | Svelte stores | NgRx, services |
| Forms | React Hook Form, Formik | vee-validate, Vuelidate | SvelteKit form actions | Reactive / Template forms |
| Data fetching | TanStack Query, SWR, `fetch` in RSC | `useFetch`, `useAsyncData`, TanStack Query | `load()`, `+page.server.ts` | `HttpClient`, `Resolve` |

**Rule:** always detect the project's actual framework before writing any component. Do not introduce another framework's idioms.

## Process

1. **Confirm the feature.** What does the user accomplish? What are the screens, the actions, the data?
   If unclear, ask one focused question — do not assume. Also confirm the **mode**:
   production (real users will hit this) or prototype (mock data, exploratory).
2. **Locate the API contract.** Endpoints, request/response shapes, errors.
   - **Production mode:** if the contract doesn't exist, stop and request
     `architecture/backend-api` work first.
   - **Prototype mode (explicitly requested by the user):** use typed mock data, define
     the contract you'd expect, mark it `// TODO: backend pending` in code, and call it
     out in the handoff.
3. **Map to layers.** Route → data hook → page component → feature components → form schema → types.
4. **Sample sibling features.** Read 1–2 *active* existing features in the same archetype.
   Active matters: an old abandoned feature might be the dead style, not the current one.
   Note the project's conventions for: data fetching library, state location, form lib,
   validator, error handling, optimistic updates, navigation.
5. **Sketch the file plan.** Where each piece lives. Apply Feature Safety Rules below.
6. **Build in layered order:** types → data layer → state → forms/validation → UI → states
   (loading/empty/error) → tests.
7. **Visual consistency check.** Delegate to `ui-designer` rules: spacing, radius, density,
   button hierarchy, form layout, empty state.
8. **Run lint, typecheck, tests.** Don't hand off broken work.
9. **Hand off.** Use `delivery/handoff`.

## Feature Safety Rules

Before implementing, internalise these. They are not aspirational; they are the floor.

1. Find 1–2 **active** sibling features with similar behaviour. Read them.
2. Identify the existing router, data-fetching library, form library, validation library,
   state strategy, and design primitives. Write them down.
3. **Do not introduce a second tool** for any of those categories. Match what exists.
4. **Do not create new shared abstractions inside a feature folder.** Shared things live
   in shared places.
5. **Do not duplicate** API types, validation schemas, query keys, or formatting helpers.
   Search before creating.
6. **Any new file requires a one-line justification** in the handoff. Files not justified
   should be reused or extended versions of existing ones.
7. **Any new dependency requires explicit user approval** before installation.
8. **New feature folders** are allowed only when the feature is truly self-contained
   (own routes, own data, own UI). Otherwise, fit it into an existing folder.

> **Detail:** read [Layer-by-layer rules](references/layer-rules.md) when you start a specific layer: routing, data, state, forms, types, UI, errors, auth, or tests.

## Side-effect discipline

Effects, watchers, and lifecycle hooks are for synchronizing with external systems only.

**Do not:** store derived state that can be computed from props, URL params, server
cache, or form state; mirror data between two state stores via effects / watchers;
trigger user-facing actions from inside an effect reacting to a boolean flag.

**Do:** use `useEffect` / `watch` / `$effect` / `ngOnInit` only to sync with a DOM API,
timer, WebSocket, or third-party library; compute derived values inline in render /
template / `computed` / `$derived`; put user-action logic in event handlers or mutation
handlers, not in effect callbacks.

## File plan template

A typical CRUD feature has: a `schema` file (validation + derived types), a data-layer
module (queries / mutations), feature components (list / form / card / empty state),
route file(s) for list / detail / create, and a test file alongside. Folder layout
follows the project's convention (`features/`, `src/lib/`, `app/`, `pages/`, `routes/`,
…) — match it, don't invent one. Read [worked file plans](references/EXAMPLES.md) when the file plan for this feature is not obvious from the repo's existing layout.

**Every file in the plan must be classified** as one of:
- **Reused** — the existing artifact is imported and used as-is
- **Extended** — an existing artifact gains a prop, option, or generic; document what was added
- **New** — nothing existing fit; one-line justification why

If the plan has more than 1–2 "new" entries, stop and look harder for reuse opportunities.

## Output format

When proposing the feature plan before implementation:

```
## Feature
<One sentence: what the user can do after this lands>

## Mode
Production / Prototype — <if prototype, what's mocked>

## Scope
- In: <bullets>
- Out: <bullets, with reason>

## API contract
- <Endpoints / hooks / RPCs needed; if missing in production mode, stop and request backend work>

## File plan
- <path> — <what>, **reused** / **extended** / **new** (one-line justification when new)

## Layers
- Routing: <approach>
- Data: <library, query keys>
- State: <local / URL / global decisions>
- Forms: <library, schema location>
- Types: <source of truth>

## Auth / permissions
- <Required role/permission, helpers reused, states handled — or N/A>

## States covered
- Default / Loading / Empty / Error / Submitting / Success / Failure
- Forbidden / Unauthenticated (if gated)

## Open questions
- <Things blocking finalization>
```

Then implement. Final handoff via `delivery/handoff`, including visual consistency notes.

## Anti-patterns

- ❌ Introducing a second data-fetching library next to the existing one
- ❌ Copying server data into local state "for convenience"
- ❌ Hand-writing validation that duplicates a schema, or vice versa
- ❌ A `useEffect` chain that fetches, transforms, and stores derived state
- ❌ Two separate type definitions for the same API resource (one in API client, one in form)
- ❌ Forms that submit twice when the user double-clicks
- ❌ Submitting then waiting then redirecting via `setTimeout`
- ❌ Toasts on every successful action regardless of whether the user can see the result
- ❌ Pages without empty / error states "because they're rare"
- ❌ Tests that assert internal function calls instead of user-visible behaviour
- ❌ Adding a new component to the design system inside a feature folder
- ❌ Building desktop-first when the project is mobile-majority
- ❌ Opting out of server-rendering wholesale (whole tree `'use client'` in Next App
  Router, or skipping SSR / server components in Nuxt / SvelteKit) to "make things easier"
- ❌ Skipping lint/typecheck/test runs and declaring done

## Notes

When the feature touches auth, theming, analytics, or navigation primitives, **reuse,
never reinvent**. Missing infrastructure is a separate concern in the handoff — don't
extend a feature into platform work silently. When in doubt about routing/data/state,
copy the most recent *active* sibling feature (old ones may be the abandoned style).
