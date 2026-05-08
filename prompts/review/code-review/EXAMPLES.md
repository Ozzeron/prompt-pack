# Examples — code-review

Sample reviews showing severity calibration, signal-to-noise, and tone.

## Example 1 — Real bug found, clean review

> ✅ Good

```
## Intent
Add a "remember me" checkbox to the login form that extends the session to 30 days.

## Findings

### 🔴 Blockers
- **src/auth/login.ts:42** — The session cookie is set with `secure: false` and
  `sameSite: 'none'`. This works in dev but ships an insecure cookie to production.
  Why: tokens travel over HTTP and are accessible to cross-site requests.
  Fix: read `secure` from the env-aware config that the rest of the app uses
  (`config.cookies.secure`), and set `sameSite: 'lax'`.

### 🟠 Major
- **src/auth/login.ts:55** — `expiresAt` is computed as `Date.now() + 30 * 24 * 60 * 60`,
  missing a `* 1000`. Sessions will expire in 30 seconds, not 30 days.
  Fix: `30 * 24 * 60 * 60 * 1000` or use `ms('30d')` (already a project dep).

### 🟡 Minor
- **src/components/LoginForm.tsx:28** — The "Remember me" label uses `<span>` instead of
  associating with the checkbox. Screen readers won't announce the label.
  Fix: `<Label htmlFor="remember-me">` or wrap the input in `<Label>`.

## What's good
- New tests cover both the checked and unchecked path
- The mutation invalidates the session cache cleanly

## Verdict
Request changes — the cookie config and the expiry math both need fixing before merge.
```

Why this works:
- Two real bugs found and explained with both impact and fix
- One useful nit (a11y), nothing performative
- "What's good" gives the author signal that the review is fair
- Verdict is decisive

---

## Example 2 — No findings of severity, lots of nits

> ✅ Good (right call)

```
## Intent
Rename `getUser` to `fetchUser` for consistency with other data hooks.

## What's good
- All 14 call sites updated
- Tests still pass
- No behaviour change

## Verdict
Approve

(No blockers, major, or minor issues found. Resisted the urge to nitpick — this is a
straightforward rename and the diff matches the intent.)
```

Why this works:
- Author isn't punished with manufactured findings
- The skill explicitly limits nits; this review took that seriously
- Verdict is fast, the PR can ship

---

## Example 3 — Diff too big

> ✅ Good (honest)

```
## Intent
"Refactor the orders module" — diff is 2,400 lines across 47 files.

## Findings

### 🟠 Major
- **PR scope** — At 2,400 lines this is too large to review thoroughly in one pass.
  I checked the public API surface (the exported functions in
  `src/orders/index.ts`) and the migration in `prisma/migrations/0078_*`.
  The rest is a sample.

  Recommend: split into 3 PRs — (1) DB migration alone, (2) data-layer changes with
  type signature audit, (3) UI integration. Each gets a focused review.

### 🟡 Minor (sampled)
- **src/orders/repository.ts:120** — `Promise.all` swallows individual rejections;
  consider `Promise.allSettled` if partial success matters.
- **src/orders/utils.ts:88** — duplicated date formatter, identical to one already
  in `src/lib/format.ts`.

## What's good
- Tests grew with the change
- The migration is additive

## Verdict
Request changes — please split. If splitting isn't feasible, I'll do a deeper second
pass but flag that I won't catch everything in one read.
```

Why this works:
- Doesn't pretend to have reviewed all 2,400 lines
- Concrete advice to split
- A few real findings as samples, not as the full review

---

## Example 4 — What NOT to do

> ❌ Bad

```
## Findings

### 🟡 Minor
- Use `const` instead of `let` here
- Variable naming could be improved
- Consider extracting this to a function
- Missing JSDoc comment
- `if/else` could be a ternary
- Could use optional chaining
- This file is getting long
- Inconsistent quotes (some single, some double)
- Trailing whitespace

## Verdict
Comment
```

Problems:
- 9 nits, all of them automated-tool territory (linter, formatter)
- Zero severity-classified findings
- "What's good" missing — author has no signal of what worked
- Verdict is non-committal — "Comment" without an opinion is noise

The code-review skill explicitly limits nits to 3 max. This review violated the spirit
by leading with style preferences instead of correctness or security.

---

## Example 5 — Security catch

> ✅ Good

```
## Intent
Add an admin-only endpoint to bulk-update user roles.

## Findings

### 🔴 Blockers
- **src/api/admin/users.ts:18** — The endpoint checks `req.user.isAdmin` but never
  verifies the JWT signature on this route. The middleware that does verification is
  applied to `/api/*` but this file mounts under `/admin/*`.
  Why: any unauthenticated user can call this with a forged `isAdmin: true` payload.
  Fix: register the auth middleware on the admin router, or wrap with
  `requireAuth + requireAdmin`. Add a test that an unauthenticated request returns 401.

### 🟠 Major
- **src/api/admin/users.ts:34** — `WHERE id IN (${ids.join(',')})` is SQL-injectable
  if `ids` ever contains a string. Prisma would normally protect, but this is a raw
  query.
  Fix: use parameterised query or Prisma's `Prisma.join`.

## What's good
- The intent is clearly scoped and the route file is tidy

## Verdict
Request changes — both findings are exploitable.
```

Why this works:
- Top finding is the kind of thing automated tools miss
- Fix is specific (auth middleware mount, not "add auth")
- Tests requested as part of the fix, not as a follow-up
