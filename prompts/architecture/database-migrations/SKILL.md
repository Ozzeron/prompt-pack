---
name: database-migrations
description: Write safe, reversible, backward-compatible database migrations. Avoid downtime, locks, and "oops we lost data".
category: architecture
version: 0.1.0
triggers: ["migration", "alter table", "schema change", "DB upgrade"]
applies_to: [openclaw, cursor, claude-code]
---

# Database Migrations

You evolve a live schema without breaking running code or losing data. Migrations are
deployed incrementally; they must be **backward-compatible with the currently-running
application** until the new code is fully rolled out.

## When to use

- Adding / removing / renaming columns or tables
- Changing types or constraints
- Adding indexes on production data
- Backfilling or transforming data
- Splitting a column into multiple, or merging columns

Do not invoke for initial schema design (`database-schema`) or for query problems (`database-review`).

## Scope

In scope:
- Migration mechanics: order of operations, expand/contract pattern
- Naming and numbering conventions
- Lock-aware DDL on Postgres / MySQL / SQL Server
- Rollback strategy
- Splitting schema migrations from data migrations

Out of scope:
- Schema design itself (use `database-schema`)
- Choosing migration tooling (Prisma, Knex, Alembic, sqlx, golang-migrate, raw SQL) —
  match what the project uses

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md)
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — read the most recent migrations only, not the whole history.
## Token discipline (specific)

- Read the most recent **5–10 migration files** to learn naming, style, tooling.
- Read the migration runner config (e.g. `prisma/migrations/`, `alembic.ini`,
  `apply-migrations.mjs`) once.
- Do NOT re-read every historical migration — they're noise for current work.

## Golden rules

1. **No destructive change in the same deploy as the code change.** Add the new shape,
   ship code that handles both, backfill, switch reads, then remove the old shape.
2. **Every migration is reversible** in concept — if the rollback isn't safe (e.g. data loss),
   say so explicitly in the migration comment.
3. **Schema migrations and data migrations are separate files.** Don't mix DDL and large
   `UPDATE` in the same step.
4. **Long-running migrations don't run inside the deploy step.** Use a job runner or a
   manual operator step.
5. **Locks matter.** A 30-second `ALTER TABLE` on a busy table = an outage. Use the
   non-blocking variants where the DB supports them.

## Expand / contract pattern (the default)

For any non-trivial schema change, split into 3+ deploys:

```
1. EXPAND   — add new shape, keep old. Ship code that writes both, reads either.
2. BACKFILL — populate new shape from old in batches.
3. SWITCH   — flip reads to new shape only. Ship the cleaned-up code.
4. CONTRACT — drop the old shape after monitoring.
```

Examples:

**Renaming a column `name` → `full_name`:**
1. Add `full_name` (nullable). Code writes both, reads `full_name OR name`.
2. Backfill `full_name = name`.
3. Make `full_name NOT NULL`. Code reads only `full_name`.
4. Drop `name`.

**Splitting `address` into structured fields:**
1. Add `street`, `city`, `postal_code` columns (nullable). Code writes structured if
   provided, falls back to `address`.
2. Backfill via parser job.
3. Switch reads to structured fields. Code stops writing `address`.
4. Drop `address`.

**Adding `NOT NULL` to existing column:**
1. Add `CHECK (col IS NOT NULL OR <legacy condition>)` as not-valid; backfill missing values.
2. Validate the check; flip column to `NOT NULL`.

## Lock-aware DDL (Postgres specifics)

| Operation | Default behaviour | Safer variant |
|---|---|---|
| `CREATE INDEX` | Locks writes | `CREATE INDEX CONCURRENTLY` (cannot be in a transaction) |
| `ALTER TABLE ADD COLUMN` (no default) | Fast, metadata only (PG 11+) | OK as is |
| `ALTER TABLE ADD COLUMN ... DEFAULT` | Rewrites table on PG <11 | PG 11+: instant for non-volatile defaults |
| `ALTER TABLE ALTER COLUMN ... TYPE` | Rewrites table | Add new column, backfill, swap |
| `ALTER TABLE DROP COLUMN` | Fast, metadata only | OK; reclaim space later via VACUUM FULL during off-hours |
| `ALTER TABLE ADD CONSTRAINT ... CHECK` | Validates immediately | Use `... NOT VALID` then `VALIDATE CONSTRAINT` separately |
| `ALTER TABLE ADD FOREIGN KEY` | Validates immediately | Same: `NOT VALID` + `VALIDATE` |

Set a short `lock_timeout` and `statement_timeout` for migrations against busy tables.

## Naming and numbering

- File: `<NNN>_<verb>_<subject>.sql` (e.g. `0042_add_orders_total_check.sql`)
- Numbers are zero-padded sequential or timestamp-based (`20260508_1430_...`)
- Verb tells you what it does: `add_`, `drop_`, `rename_`, `backfill_`, `index_`, `constraint_`
- One concern per file. If you find yourself writing "and" in the filename, split.

## Data migrations

When backfilling > a few thousand rows:

- **Batch.** `UPDATE ... WHERE id IN (SELECT id FROM ... LIMIT N FOR UPDATE SKIP LOCKED)`
- **Idempotent.** Re-running shouldn't double-apply. Use `WHERE col IS NULL` or a marker.
- **Resumable.** Track progress so a crashed job picks up where it stopped.
- **Run outside deploy.** Use a job script, not the migration runner.
- **Observable.** Log progress, failures, ETA.

## Rollback strategy

For each migration, decide upfront:

- **Trivial revert:** the down migration is the inverse DDL. Most schema-only adds qualify.
- **No-op revert:** rolling back is unsafe (would lose data). Document this. The fix-forward
  is a new migration, not a revert.
- **Partial revert:** old code can run against the new schema (the whole point of
  expand/contract). Keep both shapes during transition.

If the migration tool supports `down`, write it. If revert is unsafe, the down section
should `RAISE EXCEPTION 'irreversible: see migration NNN'` rather than silently corrupt data.

## Output format

When proposing a migration:

```
## Goal
<one-line: what state we want to reach>

## Phases
1. EXPAND  (this PR)  — file: NNN_..., changes: ...
2. BACKFILL (this PR) — file: NNN_..., script: ..., expected duration: ...
3. SWITCH  (next PR)  — code change description
4. CONTRACT (after N days) — file: NNN_..., changes: ...

## Risks
- <Locks, downtime, data correctness considerations>

## Rollback
- <Phase-by-phase: what reverting each phase requires>
```

For trivial migrations (single phase, no data change, no lock risk), skip the phases section
and just provide the SQL with a one-line comment of intent.

## Anti-patterns

- ❌ `DROP COLUMN` and `git push` in the same PR as a code change — old replicas will crash
- ❌ `ALTER TABLE ... TYPE` on a multi-million-row table during peak hours
- ❌ Adding a unique index without `CONCURRENTLY` on a busy table
- ❌ `UPDATE huge_table SET col = ...` in a migration runner — separate it
- ❌ Mixing schema DDL and `INSERT INTO config (...)` in one file
- ❌ Renaming via `ALTER ... RENAME` on a column the running app reads
- ❌ Foreign keys validated immediately on a 100M-row table — use `NOT VALID + VALIDATE`
- ❌ "I'll fix it forward" as a default — write the down migration unless it's truly impossible
- ❌ Migrations that depend on data in other tables not yet migrated — order them deterministically
- ❌ Auto-generated ORM migrations that aren't reviewed — they often produce table rewrites

## Notes

For ORMs that auto-generate migrations (Prisma, TypeORM, EF), **read the generated SQL**
before committing. Look for column type changes that imply rewrites, default values that
fire backfills, and constraint adds that validate immediately.

For Postgres specifically, see [`postgres-supabase`](../../architecture/postgres-supabase/SKILL.md)
for additional notes on RLS, Supabase migration workflow, and schema cache.
