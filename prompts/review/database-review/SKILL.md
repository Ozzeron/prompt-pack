---
name: database-review
description: Review schema, queries, indexes, migrations. Find N+1, missing indexes, lock and race risks.
category: review
version: 0.1.0
triggers: ["review schema", "DB review", "slow query", "explain plan", "review migration"]
applies_to: [openclaw, cursor, claude-code]
---

# Database Review

You audit a database schema, query, or migration for correctness, performance, and
safety. You catch what ORMs and frameworks let through silently: N+1 queries, missing
indexes, locks under load, race conditions, and migrations that look fine in dev and
break in production.

## When to use

- Slow query / endpoint reported
- Schema or migration PR up for review
- "Why is the DB CPU high?" investigation
- Pre-launch audit of new tables / queries

Do not invoke for greenfield schema design (use `architecture/database-schema`) or for
writing new migrations (use `architecture/database-migrations`).

## Scope

In scope:
- Query patterns: N+1, sequential scans, missing indexes, over-fetching
- Index health: missing, duplicate, unused, wrong order
- Lock risks: long transactions, blocking ALTER, escalation
- Race conditions: missing transactions, missing `FOR UPDATE`, double-spend patterns
- Migration safety (delegated to `architecture/database-migrations` rules)
- ORM-specific footguns (Prisma, TypeORM, SQLAlchemy, Active Record)

Out of scope:
- Whole-app architecture review
- Index tuning without `EXPLAIN` data — ask for it instead of guessing

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — naming, single responsibility, modern standards as the rubric.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — read the schema and queries in question, not the whole DB layer.

## Token discipline (specific)

- Read the specific schema files / migrations / queries provided.
- Read 1–2 adjacent tables only when relationships matter for the review.
- Do NOT read the entire migrations directory — sample the latest 3–5.
- Do NOT read application logic beyond the data layer unless asked.
- If `EXPLAIN ANALYZE` output is missing for a perf question, ask the user to run it
  rather than speculate.

## Process

1. **Understand the query / change.** Restate it in one sentence.
2. **Map data flow.** Which tables, what indexes exist (read schema), what filters apply.
3. **Check the standard symptom list** below.
4. **Classify findings** by severity (same scale as `code-review`: Blocker / Major / Minor / Nit).
5. **Recommend specific fixes** with the SQL or ORM change, not just "add an index".

## Symptom checklists

### Query smells

- **N+1**: a loop that calls a query inside it. Check ORM logs for repeated SELECTs.
- **Over-fetching**: `SELECT *` when only a few columns are used; loading whole rows for a count.
- **Sequential scan on a big table**: missing index on the filtered/joined column.
- **Hidden cast**: `WHERE id = '123'` against `bigint` triggers cast and skips index.
- **`OR` across columns**: often disables index use; consider `UNION` or covering index.
- **Pagination by `OFFSET` on large tables**: degrades linearly. Use keyset / cursor pagination.
- **`SELECT count(*)`**: always slow on large tables. Approximate (`pg_stat_user_tables`) or denormalize.
- **`ORDER BY ... LIMIT N` without supporting index**: full sort. Add an index on the order columns.
- **`LIKE '%foo%'`**: never indexed (unless trigram). Consider `tsvector`, `pg_trgm`, or full-text.

### Index health

- **Missing on FK columns**: every FK should have an index unless reads never join that direction.
- **Missing on `ORDER BY` / `WHERE` / `JOIN` columns**: pull from query plans.
- **Wrong column order in composite**: leftmost prefix rule — `(a, b)` does not help `WHERE b = ...`.
- **Duplicate indexes**: e.g. `(a)` and `(a, b)` — drop `(a)`.
- **Unused indexes**: check `pg_stat_user_indexes`; a write-tax with no read benefit.
- **Indexes on low-cardinality columns**: an index on `is_deleted` (boolean) usually doesn't help — partial index might.
- **Partial indexes**: prefer `WHERE deleted_at IS NULL` for soft-delete tables.

### Lock and concurrency

- **Long transactions**: any transaction holding row locks across multiple round trips.
- **`SELECT ... FOR UPDATE` missing**: in flows like "read balance, decide, write balance" → race condition.
- **`UPDATE ... WHERE id = ?` without re-reading first**: classic lost-update if not transactional.
- **Migration that locks during peak**: see `database-migrations` lock table.
- **Foreign key without index on referenced side**: cascading delete / update locks parent rows.

### Data correctness

- **No transaction around multi-row writes**: orphaned rows on partial failure.
- **`UPSERT` with wrong conflict target**: silently overwriting unintended rows.
- **Soft-deleted rows still being matched**: missing `WHERE deleted_at IS NULL` in app or view.
- **Float for money**: rounding errors that compound.
- **Timezone-naive timestamps**: chaos when servers/clients move zones.
- **JSONB used as a junk drawer**: critical fields buried inside, no constraints, slow filters.

### Migration safety (delegate to `architecture/database-migrations`)

Quick checks:
- DDL + data UPDATE in same migration → split
- New `NOT NULL` without backfill → broken
- New unique index without `CONCURRENTLY` on a busy table → outage
- Drop column in same release as code that reads it → outage
- Type change on big table → table rewrite, lock

### ORM-specific footguns

- **Prisma**: `findMany` in a `map` = N+1; use `include` or `select`. Default `include` may pull too much.
  Prisma migrations sometimes recreate tables for trivial type changes — review the SQL.
- **TypeORM / Sequelize**: lazy-loaded relations cause N+1; eager-load deliberately.
- **SQLAlchemy**: `lazy='select'` is the default; switch to `joined`/`selectin` for hot paths.
- **Active Record**: same N+1 trap; use `includes`/`preload`/`eager_load`.
- **Drizzle**: `with` clauses for related data; otherwise N+1.

## Output format

```
## Subject
<one-line: what is being reviewed>

## Findings

### 🔴 Blockers
- **<location>** — <issue>. Why: <impact>. Fix: <specific change>.

### 🟠 Major
- ...

### 🟡 Minor
- ...

## Recommended indexes / changes
- `CREATE INDEX CONCURRENTLY orders_user_id_created_at_idx ON orders (user_id, created_at DESC);` — supports query X
- ...

## What's good
<1-3 things done well>

## Verdict
Approve / Request changes / Comment
```

If you don't have query plans or row counts, **ask** before recommending speculative indexes.

## Anti-patterns

- ❌ "Add an index" without specifying columns and order
- ❌ Recommending denormalization for a problem caused by a missing index
- ❌ Suggesting `UUID` over `bigint` (or vice versa) without context
- ❌ Demanding caching as the fix for a missing index
- ❌ Reviewing a query in isolation — always check the schema and indexes
- ❌ Speculating on plans without `EXPLAIN ANALYZE`

## Notes

When the same question keeps coming up across reviews ("why is this slow?"), it's often a
schema or modeling issue, not a query issue. Recommend `architecture/database-schema` or
a refactor migration in those cases.
