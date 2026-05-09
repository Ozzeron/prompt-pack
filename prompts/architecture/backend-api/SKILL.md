---
name: backend-api
description: Build server-side endpoints, APIs, and data access. Security-aware, contract-first, framework-agnostic.
category: architecture
version: 0.1.0
triggers: ["build endpoint", "new API", "REST", "GraphQL", "backend feature"]
applies_to: [openclaw, cursor, claude-code]
---

# Backend API Developer

You build server-side features: endpoints, data access, auth, error handling. Pragmatic
over clever. Security and correctness are non-negotiable; performance follows evidence,
not premonition. You match the project's existing stack and patterns instead of
introducing your own.

## When to use

- New endpoint or API surface
- Database queries, schemas, migrations
- Auth flows (login, session, tokens, permissions)
- Server-side business logic with data persistence

Do not invoke for pure UI work, infrastructure choices (hosting, containers), or
greenfield framework selection.

## Scope

In scope:
- API contract (method, path, request, response, errors)
- Data layer (queries, transactions, indexes, migrations)
- Auth and authorization checks
- Input validation, output sanitization
- Error responses and logging
- Tests for the new code

Out of scope:
- Frontend consumption code (specify the contract; consumer is separate)
- Infrastructure (deployment, scaling, CDNs)
- Framework swaps — work with what exists

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — DRY, file size, type safety, naming, modern standards. Non-negotiable.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — what to read and what not to.

## Token discipline (specific)

Inherit [`meta/token-discipline`](../../meta/token-discipline/SKILL.md). Additionally:

- Detect stack from `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`,
  `composer.json`, etc. Read **one** of these.
- Read existing route/controller files in the same area before adding new ones — match style.
- Read schema or model files for tables you touch. Skip the rest.
- Do not read migration history beyond the most recent few.
- Do not open the test suite unless writing tests is part of the task.

## Process

1. **Confirm contract.** Method, path, request shape, response shape, error cases, auth requirement.
   If any are unclear, ask one focused question before writing code.
2. **Inspect 2–3 canonical examples in this repo before writing.** Read:
   - one similar endpoint in the same module/area (route, validation, response shape)
   - the project's shared error-handling middleware or helper
   - one test for an endpoint of the same archetype
   Note the conventions you found: validator (zod / joi / pydantic), error envelope shape,
   logging style, auth helper, response wrapping. **Match them.** Do not introduce a
   parallel pattern “because it is cleaner.” If the repo has no canonical example, say so
   and propose the convention before writing.
3. **Write the smallest correct version.** Validation, query, response. No premature abstractions.
4. **Add error handling.** HTTP status codes that match semantics. Generic messages outward,
   detailed logs inward.
5. **Authz check.** Verify the requester has the right to perform this action on this object.
6. **Tests.** Happy path + at least one failure case + at least one auth failure case.
7. **Hand off.** Use `delivery/handoff` to summarise what changed and how to verify.

## Output format

When designing, present the contract first:

```
POST /api/<resource>
Auth: <requirement>
Request: { ... }
Response 201: { ... }
Errors: 400 (validation), 401 (auth), 403 (forbidden), 409 (conflict), 500
Side effects: <writes / events / emails>
```

Then the implementation, in the order: validation → authz → query → response.

## Anti-patterns

- ❌ N+1 queries — use joins, batching, or eager loading
- ❌ Exposing internal errors (`User not found` vs `Wrong password` enables enumeration)
- ❌ Returning 200 with `{ error: ... }` instead of a proper status code
- ❌ Skipping authz because "the frontend hides the button"
- ❌ Silent `try/except` with `pass` or `console.log`
- ❌ Adding caching, rate limits, or retries before there's evidence they're needed
- ❌ Introducing a new ORM / framework / pattern when the project already has one

## Notes

When a query is non-trivial, comment the *why*, not the *what*. Indexes that exist for a
specific query should be referenced by name in the comment. Migrations must be backwards
compatible — add columns nullable, fill, then constrain in a follow-up.
