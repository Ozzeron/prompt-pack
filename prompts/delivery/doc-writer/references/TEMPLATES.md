# Doc-type templates

> Reference for [doc-writer](../SKILL.md). Load it when you have classified the doc type and need its template.

### README section (Quickstart-style)

````markdown
## Quickstart

```bash
# 1. Install dependencies
pnpm install

# 2. Copy environment template
cp .env.example .env

# 3. Start dev server
pnpm dev
```

Open http://localhost:3000. The `AUTH_SECRET` env var is required; see [Configuration](./docs/configuration.md).
````

> All commands above must be verified as actually runnable before including them. If you haven't run them, mark with `<!-- VERIFY: tested on node 20? -->`.

---

### ADR

```markdown
# ADR-0012: Use Zod for runtime schema validation

**Date:** 2026-03-14
**Status:** Accepted
**Deciders:** @alice, @bob

## Context

API responses from the upstream vendor are untyped. TypeScript types alone give no runtime guarantee. Several prod bugs traced to unexpected nulls in `vendor/orders.ts:88`.

## Decision

Use [Zod](https://zod.dev) for runtime validation at the ingestion boundary (`src/ingestion/parse.ts`). Validate on entry; pass typed values downstream.

## Consequences

- ✅ Runtime errors surface at the boundary, not deep in business logic
- ✅ Schema doubles as documentation
- ⚠️ ~4 KB bundle addition (acceptable for server-side code)
- ❌ Team must learn Zod API (mitigated by existing usage in `src/auth/`)

## Alternatives considered

- **io-ts** — rejected; steeper learning curve, less readable error messages
- **Manual checks** — rejected; already caused the prod bugs that prompted this ADR
```

---

### JSDoc

```javascript
/**
 * Parses a raw vendor order payload and returns a validated Order object.
 *
 * Throws `ZodError` if required fields are missing or types do not match.
 * Source of truth: `src/ingestion/schemas.ts:OrderSchema`.
 *
 * @param raw - Untyped JSON from the vendor webhook body
 * @returns Validated {@link Order}
 */
export function parseOrder(raw: unknown): Order { ... }
```

---

### Python docstring

```python
def parse_order(raw: dict) -> Order:
    """
    Validate a raw vendor payload against OrderSchema and return a typed Order.

    Raises:
        ValidationError: if required fields are absent or have wrong types.
                         See schemas.py:OrderSchema for field definitions.

    Args:
        raw: Untyped dict from the vendor webhook JSON body.

    Returns:
        Validated Order dataclass instance.
    """
```

---

### API endpoint description

```yaml
# src/routes/orders.ts:34
POST /api/orders/execute

Auth: Bearer token (scope: orders:write)
Content-Type: application/json

Request body:
  orderId  string  required  UUID of the pending order
  force    boolean optional  Skip idempotency check (default: false)

Response 200:
  { "status": "executed", "orderId": "...", "executedAt": "ISO8601" }

Response 409:
  { "error": "already_executed", "executedAt": "ISO8601" }

Response 422:
  { "error": "validation_failed", "fields": [...] }

Notes:
  - Idempotent by default; repeat calls return 409 with original timestamp
  - Enqueues a background job (src/queue/orders.ts:18) on success
```

---

### Release note entry

```markdown
## v1.4.2 — 2026-05-07

### Fixed
- Orders with null `clientRef` no longer crash the ingestion pipeline (#214, commit a3f9b12)

### Changed
- `parseOrder` now rejects payloads missing `amount` instead of defaulting to 0 (#211)
```

> Every entry must trace to a commit hash or PR number. Do not write "various bug fixes."

---
