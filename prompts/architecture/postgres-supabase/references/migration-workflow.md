# Migration workflow options

> Reference for [postgres-supabase](../SKILL.md). Load it when the task applies migrations (Supabase CLI, custom script, or dashboard SQL).

## Migration workflow

Pick **one** workflow per project and stick to it:

### Option A — Supabase CLI (recommended for new projects)
```bash
supabase migration new add_orders_table
# edit the file
supabase db push          # to local
supabase db push --linked # to remote (after staging)
```

### Option B — Custom apply script (for projects that started without CLI)
Common in Supabase projects that pre-date the migration CLI. Pattern:

```
supabase/migrations/
  20260101_initial.sql
  20260102_add_orders.sql
  ...
scripts/apply-migrations.mjs   # reads files in order, runs against DB_URL
```

The script must:
- Be idempotent (track applied migrations in a table)
- Wrap each migration in a transaction unless the file requires `CONCURRENTLY`
- Fail loud on errors

### Option C — Dashboard SQL editor
For one-off ops only. Anything ongoing goes into version control as a migration file.

**Whichever you pick, never mix.** Dashboard edits + CLI migrations = drift.
