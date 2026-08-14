-- Planted: D6 (destructive single-step migration - drops the old column in the same
-- deploy that adds the new ones, with no backfill and no rollback path)
ALTER TABLE customers ADD COLUMN first_name text NOT NULL;
ALTER TABLE customers ADD COLUMN last_name text NOT NULL;
ALTER TABLE customers DROP COLUMN full_name;
