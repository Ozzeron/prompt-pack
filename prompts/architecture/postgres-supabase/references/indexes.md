# Indexes for Supabase access patterns

> Reference for [postgres-supabase](../SKILL.md). Load it when you are adding indexes or an RLS policy is slow.

## Indexes specific to Supabase patterns

For RLS-heavy tables:
- Index every column referenced in policies (`user_id`, `org_id`, etc.)
- Composite indexes leading with the tenant column: `(user_id, created_at DESC)` for "my recent X"

For full-text search via `pg_trgm`:
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX <table>_<col>_trgm_idx ON <table> USING gin (<col> gin_trgm_ops);
```

For `jsonb` filters that are hot:
```sql
CREATE INDEX <table>_<col>_gin_idx ON <table> USING gin (<col> jsonb_path_ops);
```
