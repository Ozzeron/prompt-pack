# Recurring high-signal finding patterns

> Reference for [repo-audit](../SKILL.md). Load it when you have the project map and want the known patterns to check against.

### Recurring high-signal finding patterns

These are concrete patterns worth surfacing as findings whenever the
codebase exhibits them. Each one tends to be a real risk that users
miss in self-review.

- **OAuth callback open-redirect.** When the project has
  `/api/.../callback`, `/auth/callback`, or similar routes that read a
  `next`, `redirect`, `state.return_to`, or comparable query parameter
  and then `redirect()` to it, check whether the value is validated
  against an allowlist of internal paths. Unchecked redirect after
  successful auth is a classic open-redirect path that turns the
  legitimate auth flow into a phishing primitive. Mark it Medium or
  High depending on whether it is reachable on production.
- **OAuth/external-service error bodies leaked to the client.** When
  an `/api/.../token`, `/api/.../refresh`, or similar route returns the
  upstream provider's raw error text in the JSON response (`details:
  err`, `error: errText`), flag it. Internal error messages help
  attackers fingerprint the integration; production should return a
  generic message and log the detail server-side.
- **Inline TanStack Query keys when the project declares a key
  factory.** A skill or convention doc says "use `queryKeys.user()`"
  but the code has `queryKey: ['currentUser']` inline somewhere. The
  inline key never invalidates with the factory key; the cache silently
  diverges. Quick win every time.
- **Two layers of route protection that disagree.** A `middleware.ts`
  with a `protectedRoutes` list **and** a `(app)/layout.tsx` calling
  `getUser()`. The lists drift; new routes get covered by one but not
  the other. Flag the divergence; recommend either making layout the
  sole gate or generating the middleware list from a single source.
- **`PROGRESS.md` / `ARCHITECTURE.md` drift from code.** Counts of
  migrations, named patterns ("useState forms" vs "useSheetForm"),
  feature lists. Documentation that lies is worse than missing
  documentation; surface as a Medium finding so the user sees the
  drift even when the code is fine.

These are not exhaustive; treat them as a starting checklist for the
areas where audits most often miss real risks. Add new ones to this
list when the same finding appears across multiple audits.
