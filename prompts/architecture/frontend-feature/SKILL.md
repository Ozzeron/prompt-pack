---
name: frontend-feature
description: Build a complete frontend feature end-to-end. Routing, data, state, UI, types, validation, states, tests. Reuses existing patterns aggressively.
category: architecture
version: 0.1.0
triggers: ["build a feature", "new page", "implement screen", "add feature", "client-side feature"]
applies_to: [openclaw, cursor, claude-code]
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

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — file size, type safety, naming, modern standards.
- [`meta/reuse-before-create`](../../meta/reuse-before-create/SKILL.md) — the DRY decision flow; every "new" entry in your file plan must satisfy this skill's checks.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — sample, don't read everything.
- [`interface/ui-designer`](../../interface/ui-designer/SKILL.md) — for the UI portion: creativity calibration, restraint, visual consistency.

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

## Token discipline (specific)

- Read 1–2 sibling features to learn the project's data + state + form patterns. **If they
  conflict, read a canonical one or `AGENTS.md`/`README` before deciding.**
- Read the relevant API client / data layer entry point once.
- Read the project's form library setup (`react-hook-form`, `formik`, custom) once.
- Read the design system primitives index once (delegated to `ui-designer`).
- Do NOT read the entire `pages/` or `app/` directory.
- Do NOT read tests of unrelated features.

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

## Layer-by-layer rules

### Routing
- Match the project's router (Next.js App Router, Pages Router, React Router, TanStack
  Router, Remix). Don't introduce a second one.
- Use Server Components by default in Next.js App Router; mark `'use client'` only for
  islands that need interactivity.
- File-based routes follow project naming.

### Data layer
- Use the project's data library (TanStack Query, SWR, RTK Query, Apollo, custom). Do not
  introduce a second one.
- One **query key** per resource shape; reuse across components instead of redefining.
- Mutations invalidate or update the cache — never refetch by hand when the lib supports it.
- Server data lives in the data layer cache. Don't copy into local state without reason.
- Errors from the data layer surface as typed errors, not bare `unknown`.

### State location
Default order:
1. **Local component state** — UI-only state for one component
2. **Lifted state** — when 2 sibling components need it; lift to nearest parent
3. **URL state** — filters, tabs, selected ids, anything shareable / refresh-survivable
4. **Data layer cache** — server data, period
5. **Global store** — only for cross-cutting (auth user, theme); not for "I don't want to drill"

Derived state is computed in render, not stored.

**For list / table / dashboard pages**, prefer URL state for: filters, search, sort,
pagination cursor or page number, selected tab, and selected entity id (when a detail
panel or modal is in play). The test: if the user refreshes or shares the URL, do they
get the same view? They should.

### Forms and validation
- Use the project's form library. Don't write a parallel one.
- **Schema-first validation**: Zod / Yup / Valibot / equivalent. Define once, derive types.
- Schema lives next to the feature, in a `schema.ts` or `validation.ts` file.
- Validate on submit and on blur for fields that have already been touched.
- Submit handler:
  1. Validates (or relies on schema-resolver)
  2. Calls the mutation
  3. Handles success (close modal / navigate / toast — only one of these per submit)
  4. Handles error (field-level when applicable, top-of-form otherwise)
- Disable the submit button while pending; show inline indicator, not a global one.

### Types
- Derive from the API contract (OpenAPI, tRPC, generated client, or a hand-typed `api.ts`).
- One source of truth for shared shapes — never declare the same type in two places.
- Form types extend or pick from API types, not the other way around.
- No `any`. `unknown` at trust boundaries (API responses), narrowed via Zod.

### UI / components
Delegate to [`interface/ui-designer`](../../interface/ui-designer/SKILL.md). The summary:
- Calibrate creativity (usually A or B for in-app features)
- Reuse design-system primitives first
- Cover all states: default, loading, empty, error, plus mutation states
- Visual consistency check before handoff

### Errors
- API errors → typed → surfaced at the right level (field / form / page / global)
- Generic outward, detailed in logs
- Never swallow with `try { ... } catch {}`. Either handle or propagate
- Show retry actions where retrying is meaningful

### Auth and permissions

When a feature's visibility, actions, or data depend on user role, tenant, ownership, or permissions:

1. **Reuse existing auth/session/permission helpers.** Don't introduce a parallel auth layer.
2. **Handle all auth states explicitly:** logged-out, expired session, 401, 403, missing
   permission, role mismatch. Each gets a clear UI path — not a blank page.
3. **Hidden UI is never security.** Hiding a button does not protect the action. The
   server must enforce. Frontend permission checks are UX, not authorization.
4. **Don't render sensitive data until permission state is known.** Show a loading state
   while resolving, not optimistic content that flickers and exposes.
5. **Don't log or expose sensitive data on the client:** tokens, session payloads, raw
   API errors with internals, PII in console or analytics.

### Tests
- Test behaviour, not implementation. "When user clicks Save, the API is called with X
  and the toast appears" — not "the `handleSave` function is called."
- Use the project's testing library (Vitest, Jest, Playwright). Don't introduce a parallel one.
- Mock the data layer at its boundary (handler / fetcher), not at random places.

**Minimum coverage for an interactive feature:**
- One happy path (mutation succeeds, UI reflects it)
- At least one validation case (form rejects bad input)
- At least one failure case (API error → user-visible message)
- Loading state renders
- Empty state renders
- Permission / forbidden state renders (when the feature is gated)
- URL state persists across reload (when filters / pagination / tabs are URL-bound)
- Duplicate submit is prevented (rapid double-click on Save)
- Cache invalidation after mutation works (list updates after item is created/edited/deleted)

Not every feature needs all nine — cover the ones that apply to *this* feature.

## File plan template

For a typical CRUD feature, expect something like:

```
features/<feature>/
  schema.ts             # Zod schemas, derived types
  api.ts                # data hooks: useX, useXMutation
  components/
    <Feature>List.tsx
    <Feature>Form.tsx
    <Feature>Card.tsx
    <Feature>EmptyState.tsx
  pages/
    index.tsx           # list page
    [id].tsx            # detail page
    new.tsx             # create page (or modal trigger)
  __tests__/
    <feature>.test.tsx
```

Match the project's actual conventions — this is just a shape, not a prescription.

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
- ❌ Marking the whole tree `'use client'` to "make things easier" in Next.js App Router
- ❌ Skipping lint/typecheck/test runs and declaring done

## Notes

When the feature touches auth boundaries, theming, analytics, or navigation primitives,
**reuse, never reinvent**. If the existing infrastructure is missing something, flag it as
a separate concern in the handoff — don't extend a feature into platform work silently.

When in doubt about routing/data/state choices, copy the most recent and most active
sibling feature. Active matters: an old feature might be the abandoned style, not the
current one.
