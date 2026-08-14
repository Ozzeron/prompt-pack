---
name: postgres-supabase
description: "Handles Postgres and Supabase specifics: row-level security policies, auth.uid() and auth.users integration, the supabase CLI migration workflow, PostgREST and schema-cache quirks, and storage bucket policies. Use when the project runs on Supabase, when RLS blocks or leaks rows, or when PostgREST returns a schema-cache error. Not for vendor-neutral schema design (database-schema) or non-Postgres databases."
license: MIT
metadata:
  pp-category: architecture
  pp-version: "0.2.0"
  pp-activation: native
  pp-surfaces: "openclaw, cursor, claude-code"
---

# Postgres + Supabase

You work with Supabase: Postgres database, auth, storage, edge functions. This skill
captures the platform-specific decisions and traps that the generic database skills don't
cover. Covers self-hosted Postgres too where it overlaps.

## When to use

- Designing or modifying tables on a Supabase project
- Writing or debugging RLS policies
- Setting up auth.users → public schema integration
- Migration workflow (CLI, dashboard, custom scripts)
- Schema cache issues, PostgREST quirks
- Storage bucket policies

Do not invoke for generic schema design (use `architecture/database-schema`) or for
non-Postgres databases.

## Scope

In scope:
- RLS policy design (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, with `USING` and `WITH CHECK`)
- `auth.users` integration: triggers to mirror into `profiles`, FK setup
- Postgres-specific features: `jsonb`, partial indexes, generated columns, materialized views
- PostgREST schema cache and reload (`NOTIFY pgrst, 'reload schema'`)
- Supabase migration workflows (`supabase migration new`, custom apply scripts, dashboard)
- Storage bucket creation and access policies
- Edge functions ↔ DB integration

Out of scope:
- Pure SQL query tuning (use `review/database-review`)
- Frontend Supabase client patterns

## Inherits

- [`architecture/database-schema`](../database-schema/SKILL.md) — base conventions.
- [`architecture/database-migrations`](../database-migrations/SKILL.md) — base migration safety.
- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md)
- [`meta/reuse-before-create`](../../meta/reuse-before-create/SKILL.md) — before writing a new RLS policy, helper function, or auth predicate, check existing policies and `auth.*` helpers for one to reuse or extend.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md)
## Token discipline (specific)

- Read the project's `supabase/migrations/` directory — last 3–5 files only.
- Read `supabase/config.toml` once if it exists.
- For RLS questions: read the relevant table's existing policies via SQL or migration; do
  not re-read the whole RLS history.
- Skip generated TypeScript types unless types are part of the question.

## RLS — Row Level Security

RLS is **off by default** on a new table. **Turn it on for every table the API touches.**

```sql
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders FORCE ROW LEVEL SECURITY; -- also enforces for table owner
```

### Policy structure

A policy controls one operation (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) for one role
(usually `authenticated` or `anon`).

```sql
CREATE POLICY orders_select_own ON public.orders
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY orders_insert_own ON public.orders
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY orders_update_own ON public.orders
  FOR UPDATE
  TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));
```

- `USING` — which existing rows the user can see / target
- `WITH CHECK` — which new/changed rows are allowed (after the operation)
- `UPDATE` needs both — `USING` for the rows visible to update, `WITH CHECK` for the
  resulting state

### Performance

- **Wrap `auth.uid()` in a subselect** — `(SELECT auth.uid())` — Postgres caches the result
  per query. Repeated calls without the subselect re-evaluate.
- **Index the columns RLS filters on.** A policy `WHERE org_id = ...` needs an index on `org_id`.
- **Test policies under load** — RLS adds predicates to every query plan. Check `EXPLAIN`.
- **Service role bypasses RLS.** The `service_role` key in server-side code skips all
  policies. Never expose this key to clients.

### Common RLS pitfalls

- ❌ Forgetting to enable RLS — table is wide open via API
- ❌ Only writing a `SELECT` policy and assuming it covers writes — each operation needs its own
- ❌ `USING (true)` on a public-read table without thinking about indexes (still adds plan cost)
- ❌ Recursive policy: a policy that joins to another table whose policy joins back
- ❌ Calling `auth.uid()` directly without subselect on hot queries
- ❌ Putting expensive function calls in policies (each row gets evaluated)

## auth.users integration

Supabase manages users in the `auth` schema. Your data lives in `public`. The link is:

```sql
-- profiles table mirrors auth.users
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  full_name text,
  created_at timestamptz DEFAULT now()
);

-- trigger: when a new auth.users row is created, mirror to profiles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

Notes:
- Use `SECURITY DEFINER` carefully — the function runs as the function owner. Pin
  `search_path` to avoid hijack.
- `ON DELETE CASCADE` mirrors auth deletes. Decide if you actually want this — for soft
  delete, drop the cascade and handle in app code.

> **Detail:** read [Migration workflow options](references/migration-workflow.md) when the task applies migrations (Supabase CLI, custom script, or dashboard SQL).

## Schema cache (PostgREST)

The Supabase REST API is PostgREST. It caches the schema at startup; new tables/columns
don't appear until reload.

```sql
NOTIFY pgrst, 'reload schema';
```

Run this at the end of any migration that adds tables, columns, or RLS policies if you're
calling the REST API right after.

In Supabase the dashboard does this for you on visible operations; custom migration
scripts must include it.

## Common pitfalls

- ❌ Tables created without RLS enabled — silent data exposure
- ❌ `service_role` key in client-side code or `.env.local` committed to a frontend repo
- ❌ Treating `auth.users` like a regular table — never insert directly, always via auth API
- ❌ Storage policies forgotten — bucket is private but uploaded files are accessible
- ❌ Edge functions using `service_role` for tasks that should respect RLS (e.g. user actions)
- ❌ `SELECT *` in dashboards on tables with sensitive columns — RLS doesn't filter columns,
  only rows. Use views or column-grant for column-level security
- ❌ Dropping a column that an RLS policy references — policy breaks silently
- ❌ Migration scripts that don't `NOTIFY pgrst, 'reload schema'` — REST API 404s

> **Detail:** read [Indexes for Supabase access patterns](references/indexes.md) when you are adding indexes or an RLS policy is slow.

## Output format

For RLS policy proposals:

```sql
-- Goal: <one-line>
ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;

CREATE POLICY <name> ON public.<table>
  FOR <op>
  TO <role>
  USING (<predicate>)
  WITH CHECK (<predicate>);  -- if applicable

-- Required indexes:
CREATE INDEX ... ON public.<table> (...);
```

For migration proposals: follow `architecture/database-migrations` output format, plus
include `NOTIFY pgrst, 'reload schema';` at the end if needed.

## Hand off

For RLS, auth-integration, or migration-workflow changes, finish with `delivery/handoff`
summarising:

- which tables/operations the new policies cover and which remain unprotected
- the role surface (`anon`, `authenticated`, `service_role`) per policy and why
- indexes added to support policy predicates (and which queries they unblock)
- whether `auth.users` columns are read directly or via a subselect (perf note)
- schema-cache reload needed (`NOTIFY pgrst, 'reload schema';`) yes/no
- pitfalls applicable to this change (RLS off after pg_dump restore, dashboard-vs-CLI drift)

Skip handoff for single-policy tweaks on already-secured tables where the diff is obvious.

## Anti-patterns

- ❌ Tables in `public` without RLS
- ❌ Policies that don't index the columns they filter on
- ❌ Re-using the same policy across operations (always per-op)
- ❌ `auth.uid()` called directly in hot policies (use subselect)
- ❌ `service_role` key in any client bundle
- ❌ Mixing dashboard edits and CLI migrations
- ❌ Storage buckets created without bucket policies
- ❌ Trigger functions without `SECURITY DEFINER SET search_path = public` when they should have it

## Notes

When auditing an existing Supabase project, the **first thing to check** is whether RLS is
enabled on every public table. The second thing is whether `service_role` keys leaked into
any client. Those two account for most Supabase incidents.
