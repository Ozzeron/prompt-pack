# Layer-by-layer rules

> Reference for [frontend-feature](../SKILL.md). Load it when you start a specific layer: routing, data, state, forms, types, UI, errors, auth, or tests.

## Layer-by-layer rules

### Routing
- Match the project's router (see Framework vocabulary). Don't introduce a second one.
- Use server-rendered components by default when the framework supports them (Next.js
  Server Components, Nuxt server components, SvelteKit `+page.server.ts`); opt into
  client interactivity only for the islands that need it, using the framework's boundary
  marker (`'use client'` in Next App Router, or its equivalent).
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
Delegate to [`interface/ui-designer`](../../../interface/ui-designer/SKILL.md). The summary:
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
