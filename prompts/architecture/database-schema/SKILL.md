---
name: database-schema
description: "Designs a database schema: table and column naming, key and type choices, indexes, soft-delete and audit columns, multi-tenant boundaries, plus document-store notes. Use when modelling new tables or collections, restructuring data such as one-to-many into many-to-many or splitting a god-table, or designing the data layer before the API. Not for query tuning (database-review) or writing the migration itself (database-migrations)."
license: MIT
metadata:
  pp-category: architecture
  pp-version: "0.2.0"
  pp-activation: native
  pp-surfaces: "openclaw, cursor, claude-code"
---

# Database Schema Designer

You design or extend a database schema for a feature or product. The goal is a schema
that's **correct now and bendable later** — not perfect upfront, not impossible to evolve.
You favour fewer surprises over theoretical purity.

## When to use

- New tables / collections for a feature
- Restructuring existing data (one-to-many → many-to-many, splitting a god-table)
- Designing the data layer before writing the API

Do not invoke for query optimisation (use `review/database-review`) or migration
mechanics (use `architecture/database-migrations`).

## Scope

In scope:
- Tables / collections, columns, types, constraints
- Primary keys, foreign keys, indexes
- Soft-delete and audit-column decisions
- Enums vs lookup tables vs check constraints
- Multi-tenant / scoping decisions
- Naming conventions

Out of scope:
- Migration mechanics — see `database-migrations`
- Query patterns and indexing for known queries — see `database-review`
- Cache and eventual-consistency strategies — separate concern

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — naming, single responsibility, modern standards apply to schemas too.
- [`meta/reuse-before-create`](../../meta/reuse-before-create/SKILL.md) — before adding a new table, enum, or join table, look for an existing entity that already covers the shape or that should be extended instead.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — read existing migrations and one or two adjacent schemas, not the whole history.
## Token discipline (specific)

- Read the project's existing migrations directory **only the most recent 5–10 files** to
  learn naming and style.
- Read 1–2 nearby table definitions to match conventions.
- Skip seed data, test fixtures, and ORM-generated boilerplate.

## Process

1. **Clarify the domain.** What entities exist? What are the relationships? What are the
   read patterns vs write patterns?
2. **Inspect 2–3 canonical examples in this schema before designing.** Read:
   - one nearby table in the same domain (column types, naming, FK style)
   - one recent migration that touched a similar shape (how additions are normally rolled out)
   - the project's id strategy (uuid v4 / v7 / bigint serial / nanoid) and timestamp
     convention (`created_at` / `inserted_at`, with or without `updated_at`, timezone
     handling)
   Note conventions for: primary key type, soft-delete column name (or absence),
   audit columns, enum-vs-lookup-table style, JSON/JSONB usage, naming case (snake
   vs camel). **Match them.** If the project has multiple competing styles, pick the
   most recent and call out the inconsistency in the handoff.
3. **Pick the lowest-friction shape** that handles current + obvious-near-future needs.
   Don't model imagined requirements.
4. **Decide soft-delete.** Default to hard delete + audit log, switch to soft-delete when
   the domain genuinely needs reversibility (medical records, legal documents).
5. **Place indexes** for the queries you know exist. Avoid speculative indexes.
6. **Define constraints** (NOT NULL, UNIQUE, CHECK, FK) — let the database enforce invariants.
7. **Document the decision** — one paragraph in the migration or schema file explaining
   the non-obvious choices.
8. **Hand off.** For non-trivial schema changes, finish with `delivery/handoff` summarising
   the entities added/changed, the index strategy, the constraints enforced, what
   downstream code/migrations will need to follow, and any open questions.

## Conventions (relational)

### Naming
- Tables: `snake_case`, **plural** (`users`, `order_items`, `payment_methods`)
- Columns: `snake_case`, singular (`first_name`, `created_at`)
- Primary key: `id` (`uuid` or `bigint` depending on scale and ecosystem)
- Foreign keys: `<singular_table>_id` (`user_id`, `order_id`)
- Indexes: `<table>_<columns>_idx` (`orders_user_id_created_at_idx`)
- Constraints: `<table>_<column>_<kind>` (`users_email_unique`, `orders_total_check`)

### Standard columns
Every entity table gets:
- `id` — PK
- `created_at` — `timestamptz` default `now()`
- `updated_at` — `timestamptz` default `now()`, updated by trigger or app code
- `created_by` / `updated_by` — only when audit is meaningful

Add `deleted_at` (`timestamptz` nullable) **only** when you decide on soft-delete.

### Types
- IDs: `uuid` for distributed/public systems, `bigint`/`bigserial` for internal
- Money: `numeric(precision, scale)` (e.g. `numeric(12, 2)`), **never floats**
- Timestamps: always with timezone (`timestamptz`)
- Strings with known max: `varchar(N)` only if N is a real domain limit; otherwise `text`
- Enums: see "Enum strategy" below
- JSON: `jsonb` (Postgres) when the shape is genuinely variable; `text` columns of JSON are wrong

### Enum strategy
Three options, pick by stability and use:

| Strategy | When to use | Notes |
|---|---|---|
| **DB enum type** | Values are stable, ≤10 items, code references them | Hardest to extend in some DBs (Postgres now has `ALTER TYPE ... ADD VALUE`) |
| **Lookup table + FK** | Values are user-editable or have metadata (label, color, sort) | Most flexible, joins required |
| **`check` constraint on text** | Values are stable, app-driven, no metadata | Easy to add values, no join, must keep DB and code in sync |

Default to **`check` on text** for status-like fields unless you need extra metadata.

### Soft delete vs hard delete

Default: **hard delete + audit table** for ops actions.

Switch to soft delete when:
- Reversibility is a product requirement (trash bin, restore)
- Regulatory retention (medical, legal, financial)
- Foreign keys would cascade-delete user-meaningful data

When using soft delete:
- Add `deleted_at timestamptz` (nullable)
- Every query MUST filter `deleted_at IS NULL` — wrap in a view or repository helper
- Unique constraints become partial: `UNIQUE (email) WHERE deleted_at IS NULL`
- Cascading and FK behaviour needs explicit decisions

### Multi-tenant / scoping

If multiple users / orgs share the same tables:
- Add a tenant column (`org_id`, `workspace_id`, `user_id`) to **every** scoped table
- Every query MUST include the tenant filter; enforce at the DB layer (RLS, views) when possible
- Indexes must include the tenant column as the leading column for scoped queries

## Conventions (document stores)

For Mongo, Firestore, DynamoDB:
- Embed when reads are aggregate-shaped and writes don't fan out
- Reference when the embedded entity has its own lifecycle or grows unbounded
- Index only what you query; secondary indexes cost on every write
- Pick a partition / shard key that distributes writes evenly and matches the dominant read

## Output format

```
## Domain
<Entities, relationships, key read/write patterns>

## Schema

### <table_name>
| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | uuid | PK | |
| ... | ... | ... | |

Indexes:
- <name> on (cols) — for query <q>

### <next_table>
...

## Decisions
- <Soft delete: yes/no, why>
- <Multi-tenant: yes/no, scope column>
- <Enum strategy: chosen approach, why>
- <Anything non-obvious>

## Open questions
- <Things the user must answer before this is final>
```

## Anti-patterns

- ❌ `varchar(255)` everywhere — pick a real limit or use `text`
- ❌ `float`/`double` for money
- ❌ `timestamp` (without TZ) for events — use `timestamptz`
- ❌ Enum tables with single column `name` — that's a check constraint
- ❌ Soft-delete as default "just in case" — pick deliberately
- ❌ FK to a table that may be soft-deleted, with cascade delete
- ❌ Indexes on every column — they cost on every write
- ❌ `data jsonb` as a junk drawer for "we'll figure it out later"
- ❌ Polymorphic associations via `type + id` columns — usually a sign of missing modeling
- ❌ Designing for hypothetical scale before the product has 100 users

## Notes

When in doubt between two reasonable shapes, pick the one that's easier to migrate **away
from**. Optionality > optimality at the start of a project.
