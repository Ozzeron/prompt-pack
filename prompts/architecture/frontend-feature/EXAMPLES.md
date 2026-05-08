# Examples — frontend-feature

Worked examples showing what the skill produces. Each pairs a user request with the
expected planning output and (where useful) a commentary on what the skill prevented.

---

## Example 1 — User settings page (production mode)

**Request:**
> "Build a settings page where users can update their name, email, and notification
> preferences. We're on Next.js 15 + Supabase, project already in production."

**Project context the agent reads first:**
- `package.json` — react-hook-form, zod, date-fns, no Redux/Zustand, no Day.js
- `src/lib/auth/actions.ts` — existing zod schema patterns, server actions
- `src/components/add-transaction-dialog.tsx` — sibling RHF feature for reference
- `supabase/migrations/` — confirms `profiles` table has `notification_preferences jsonb`

**Expected planning output:**

```
## Feature
Logged-in users can edit their name, email, and notification preferences from a settings
page; changes persist to Supabase and the session reflects the new values immediately.

## Mode
Production — API contract derived from existing `profiles` table schema.

## Scope
- In: settings page route, profile form, mutation hook, optimistic UI, validation,
  loading/empty/error/success states, role-protected route
- Out: avatar upload (separate ticket), email-change verification flow (security review
  needed), audit log (separate concern)

## API contract
- Route: `app/(authenticated)/settings/profile/page.tsx`
- Server action: `updateProfile({ name, email, notification_preferences })` in
  `src/lib/profile/actions.ts`
- Returns: updated profile or typed error
- Auth: requires authenticated user; users can only update their own profile (RLS enforces)

## File plan
- `src/lib/profile/schema.ts` — **new** — Zod schema; project has no shared profile schema yet
- `src/lib/profile/actions.ts` — **new** — `updateProfile` server action; mirrors patterns from `auth/actions.ts`
- `src/app/(authenticated)/settings/profile/page.tsx` — **new** — settings page route
- `src/app/(authenticated)/settings/profile/profile-form.tsx` — **new** — form component
- Reused: `Button`, `Input`, `Label`, `Card` from `components/ui/`
- Reused: `useFormStatus` from React, RHF + zod resolver pattern from sibling features
- Reused: Supabase client from `src/lib/supabase/server.ts`

## Layers
- Routing: Next.js App Router, server component shell + client form island
- Data: server actions; no client-side fetching library needed
- State: form state in RHF; server state via revalidatePath after mutation
- Forms: react-hook-form + zod resolver
- Types: derived from Zod schema via `z.infer`

## Auth / permissions
- Page: requires authenticated session (middleware already enforces)
- Action: server-side `auth.uid()` check + RLS policy on `profiles.user_id = auth.uid()`
- States handled: not authenticated → redirect to login (middleware); session expired → 401 path

## States covered
- Default / Loading / Submitting / Success (inline confirmation) / Failure (form-level error)
- Forbidden (handled by middleware before page renders)

## Open questions
- Does email change require re-verification? If yes, this is out of scope here
  and routes to a separate skill.
```

What the skill prevented:
- Did not introduce a global state library (no Redux for "user settings global state")
- Did not introduce a date library (existing date-fns covers any timestamps needed)
- Did not invent a new auth pattern (reused middleware + RLS already in place)
- Each "new" file in the plan has a one-sentence justification

---

## Example 2 — Prototype mode with mock data

**Request:**
> "Mock up a dashboard for the marketing site. We don't have the API yet, just want
> to see the layout and demo it tomorrow."

**Expected planning output (excerpt):**

```
## Mode
Prototype — explicitly requested by user; API contract pending.

## Scope
- In: dashboard layout, sample chart, sample stats grid, mock data wired through typed
  module that can be swapped for real hooks later
- Out: real data fetching, error states (mocks don't error), pagination

## API contract
- Pending; mock module at `src/features/dashboard/mock-data.ts` with `// TODO: backend pending`
- Defined the shape that real endpoints will need to satisfy:
  ```ts
  type DashboardStats = {
    activeUsers: number;
    revenueThisMonth: number;
    topReferrers: { name: string; visits: number }[];
  };
  ```

## Risks (production carryover)
- All "data" is hardcoded; nothing reflects real user state
- Real backend may change the contract; mock module is the integration seam
- Loading/error/empty states are not exercised — wire them once real hooks land

## Out of scope (will need follow-up)
- Real API integration
- Loading / error / empty state coverage
```

What the skill enforced:
- The prototype mode was acknowledged explicitly, not assumed
- Mock data is typed (matches the eventual contract shape)
- Risks of mocks are surfaced — handoff and reviewers know what's unverified

---

## Example 3 — Refusal: forced second tool

**Request:**
> "Build a quick form. Use Redux Toolkit for state and Day.js for the timestamp
> display. Add `@reduxjs/toolkit` and `dayjs` to package.json."

**Project context:**
- react-hook-form already used in 8 components
- date-fns already in dependencies
- No Redux anywhere

**Expected response:**

```
Before I add those dependencies — flagging tool duplication that the skill won't let
me commit silently:

| Requested | Already in project | Verdict |
|---|---|---|
| @reduxjs/toolkit | No global state lib; this is a single form's local state | ❌ Reject — overkill |
| dayjs | date-fns covers timestamp formatting | ❌ Reject — duplicates existing date library |

The right shape for a form like this:
- Local form state via `react-hook-form` (matches every other form in the project)
- Validation via zod (matches the established pattern)
- Timestamp display via `formatDistanceToNow(date)` from `date-fns`

If you have a specific reason to introduce Redux Toolkit (start of a broader global
state strategy?), let's discuss the architecture first. I won't add new deps without
that conversation.

Want me to proceed with the existing stack?
```

What the skill prevented:
- Refused to silently add two new dependencies that duplicate existing ones
- Surfaced the architectural decision to the user instead of making it
- Pointed to the existing patterns and exact functions that already do the job

---

## Notes

These examples are illustrative, not regression fixtures. The point is to show the
*shape* of what `frontend-feature` produces — not to provide a copy-paste output.
The actual behaviour depends on the real project state, which the skill instructs
the agent to discover before planning.
