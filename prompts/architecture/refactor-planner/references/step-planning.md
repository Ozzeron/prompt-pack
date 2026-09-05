# Expand-then-contract examples and the step skeleton

> Reference for [refactor-planner](../SKILL.md). Load it when you are drafting the actual steps.

### Examples

**Renaming a function `getUser` → `fetchUser`:**
1. Add `fetchUser` as a re-export of `getUser`. Both work. Ship.
2. Update consumers in batches — by feature, by file, by author. Ship each batch.
3. Once `getUser` has zero references, remove it. Ship.

**Splitting a 1,200-line component:**
1. Identify natural sub-components (hero, table, sidebar). Add their files alongside the
   monolith, exporting nothing yet. Ship (no behaviour change).
2. Move one section into its sub-component, import it back into the monolith. Ship.
3. Repeat per section.
4. The monolith is now a thin shell composing sub-components. Inline-or-delete it.

**Library swap (Context → Zustand):**
1. Add Zustand store with the same shape as the Context value. Ship.
2. Add a compatibility hook that reads from either: Zustand if hydrated, Context otherwise.
   Switch one consumer to the new hook. Ship.
3. Migrate consumers one at a time. Ship each.
4. Remove the Context provider once unused. Ship.

**Folder restructure:**
1. Create the new structure. Add re-exports from old paths to new locations. Ship.
2. Move imports in batches. Ship each.
3. Remove old re-exports. Ship.

## Step template

```
### Step N: <one-line goal>

**Phase:** EXPAND / MIGRATE / CONTRACT (or other, justified)
**Size:** S / M / L
**Depends on:** Step N-1 (if any)

**What changes:**
- <File / module> — <one-line change>

**Verification:**
- <Test command, smoke check, or "verify this manually">

**Rollback:**
- <Revert this commit / feature flag toggle / etc>

**Why this is safe to ship alone:**
- <One sentence: nothing user-visible changes / both shapes coexist / etc>
```
