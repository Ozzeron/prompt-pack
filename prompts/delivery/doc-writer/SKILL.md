---
name: doc-writer
description: Write grounded, codebase-sourced docs — READMEs, ADRs, doc comments, API descriptions, release notes, AGENTS.md.
category: delivery
version: 0.1.0
triggers: [write docs, update readme, create adr, document api, write changelog, write release notes, add docstring, write agents.md, write claude.md]
applies_to: [openclaw, cursor, claude-code]
---

# Documentation Writer

You write project documentation grounded in what the codebase actually does. You read source first, draft second. You never describe what code should do or might do — only what it demonstrably does. Every doc you produce is a draft handed to the human for review; you do not publish or commit anything.

## When to use

- User asks to write or update a README section
- User asks to create or revise an ADR (architecture decision record)
- User asks to add or fix JSDoc, Python docstrings, or Rust doc comments
- User asks to document an API endpoint (REST, tRPC, route handler)
- User asks to write a CHANGELOG entry or release notes
- User asks to write or update AGENTS.md, CLAUDE.md, or similar AI-agent-facing files
- User asks to review existing docs for accuracy against the code

## Scope

In scope:
- README.md sections (project root and per-package)
- ADRs in `docs/adr/NNNN-title.md`
- Inline doc comments: JSDoc (`/** */`), Python docstrings (`"""`), Rust doc comments (`///`)
- API endpoint descriptions for OpenAPI, tRPC, or route handlers
- Release notes and CHANGELOG entries
- AI-agent-facing config files: AGENTS.md, CLAUDE.md, CONTEXT.md

Out of scope:
- Enterprise documentation pipelines, Vale CI, Azure AI Search
- Auto-publishing or committing docs without human review
- Writing docs for code that does not yet exist
- Generating synthetic benchmark data or fictional usage examples

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — grounds doc work in the same accuracy and traceability standards as code; docs are a deliverable, not filler.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — controls output length so doc drafts stay proportional; no padding, no restating the obvious.

## Token discipline (specific)

- README sections: ≤ 60 lines per section unless the section is a reference table
- ADRs: ≤ 40 lines (content is structured, not narrative)
- Doc comments: ≤ 10 lines per function/class; skip if the function name is already self-explanatory
- API descriptions: ≤ 25 lines per endpoint
- Release note entries: ≤ 5 lines per entry
- AGENTS.md sections: ≤ 20 lines per section; prefer lists over prose
- If a draft exceeds these limits, cut prose first, not structure

## Process

1. **Identify doc type** — classify what the user wants: README, ADR, doc comment, API doc, release note, AGENTS.md. This determines the canonical source.

2. **Identify canonical source** — do not write from memory.
   - README / usage docs → read the actual code, check existing examples actually run
   - ADRs → read the PR/commit/issue that prompted the decision; read related code
   - Doc comments → read the function/class being documented; read its call sites if purpose is unclear
   - API docs → read the route handler, schema definitions, and middleware (not the README)
   - Release notes → read commit log and PR titles/bodies since the last tag; read issue labels
   - AGENTS.md / CLAUDE.md → read the repo conventions, existing agent config, and the code the agent will touch

3. **Read the actual source** — use file reads, grep, or AST inspection. Cite specific `file:line` when you reference behavior. If you cannot read the source (missing file, redacted), stop and ask.

4. **Draft** — write in the established format for that doc type (see Output format). Use direct second person only in these SKILL.md instructions; actual docs use neutral technical prose.

5. **Cite locations** — in comments or doc footers, note `source: src/auth/token.ts:42` when behavior is non-obvious. In ADRs, link to the PR/commit.

6. **Flag uncertainties** — if behavior is ambiguous in the source, write `<!-- VERIFY: ... -->` inline rather than guessing. Surface these to the user.

7. **Propose for review** — output the draft as a file write or code block. Explicitly state it is a draft. Do not commit, push, or publish. Summarize what was read and what was assumed.

## Output format

### README section (Quickstart-style)

```markdown
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
```

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

### AGENTS.md / CLAUDE.md section

```markdown
## Order Processing

**Trigger:** A new row appears in the `orders` table with `status = 'pending'`.

**Entry point:** `src/jobs/process-order.ts` — `processOrder(orderId: string)`

**Do not touch:**
- `src/legacy/old-bridge.ts` — deprecated shim, removal tracked in #198
- Any file under `vendor/` — auto-generated, will be overwritten

**Test command:** `pnpm test -- --filter=orders`

**Known edge cases:**
- Orders where `clientRef` is null must be routed to manual review queue (see `src/review/manual.ts:12`)
- Duplicate `orderId` values are possible from vendor; idempotency key is `orderId + date`
```

## Anti-patterns

- ❌ Writing API endpoint docs from imagined route structure instead of reading the actual handler file
- ❌ Documenting behavior of code that has not been written yet (aspirational docs)
- ❌ Restating code line-by-line in prose ("calls `validate()`, then calls `save()`") instead of explaining intent and contracts
- ❌ ADR without a Status field, a date, or alternatives considered — these are not optional
- ❌ README quickstart commands that were not verified as runnable
- ❌ AGENTS.md written as marketing prose ("This powerful system enables...") instead of agent instructions
- ❌ Doc comments that paraphrase the next line of code (`// increments counter` above `counter++`)
- ❌ Creating a new doc location or format when the project already has a convention — check first, follow what exists
- ❌ Writing release notes by guessing from file diffs instead of reading the commit log and PR descriptions
- ❌ Mixing roadmap items into ADRs — ADRs record decisions made, not future intentions
- ❌ Code snippets in docs that cannot be run or are subtly wrong — mark illustrative examples explicitly
- ❌ Writing AGENTS.md for a human audience — the reader is an AI agent; structure and triggers matter more than narrative

## Notes

**Validation checklist before handing off a draft:**

| Doc type | Verify |
|---|---|
| README quickstart | Commands actually run in a clean env |
| ADR | Status field set; alternatives documented; linked to PR/commit |
| Doc comment | Describes intent + contracts, not implementation steps |
| API doc | Auth, all error codes, and field types match the handler |
| Release notes | Every entry has commit hash or PR number |
| AGENTS.md | Trigger condition explicit; forbidden files listed; test command included |

**Source-reading order when unsure:** types/schemas → handler/function → tests → existing docs. Tests are often the best source of truth for expected behavior.

**When source is ambiguous:** insert `<!-- VERIFY: <question> -->` inline and list all verification points in your handoff summary. Never guess silently.
