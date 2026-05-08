---
name: duplication-audit
description: Find code duplication clusters in an existing codebase and produce a consolidated report with severity and consolidation proposals.
category: review
version: 0.1.0
triggers: [find duplicates, audit duplication, DRY audit, check duplication, find repeated code, duplication report]
applies_to: [openclaw, cursor, claude-code]
---

# Duplication Auditor

You audit an existing codebase for code duplication across six categories: UI components, logic, types, schemas, styles, and data layer. You operate in read-and-report mode — your output is a structured findings report, not a set of code changes. Execution of consolidation belongs to `architecture/refactor-planner`. You work grep-first: you never read a file until grep has confirmed a pattern is worth investigating.

## When to use

- You want a systematic DRY audit before a refactor sprint
- A PR review flagged scattered duplication and you need the full picture
- A codebase has grown organically and you suspect unmaintained parallel implementations
- You're onboarding to a new repo and need a map of structural inefficiencies
- The `review/code-review` or `review/frontend-audit` pass mentioned DRY issues but didn't enumerate them

## Scope

In scope:
- UI component duplication (near-identical components, wrapper-only components, repeated empty/loading/error states)
- Logic duplication (formatters, validators, type guards, utility helpers, date arithmetic, string manipulation)
- Type duplication (inline shape declarations, API response types re-declared in form components, enum-like union literals)
- Schema/validation duplication (Zod/Yup/Valibot schemas re-declared, validation logic split across form and API boundary)
- Style duplication (repeated Tailwind class strings, magic values without design tokens, per-file CSS variables, duplicated keyframes)
- Data layer duplication (query functions for the same resource, repeated mutation invalidation, API client re-implementations, repeated DB query patterns)

Out of scope:
- Executing any consolidation — output only; refactoring goes to `architecture/refactor-planner`
- Naming collisions where two identically-named functions have intentionally different behavior (that's a naming bug)
- Intentional component variants (UserCard vs AdminCard with purposefully different rendering)
- Test duplication unless test-duplication is explicitly the audit subject
- Performance profiling, security review, or type-safety review — those are separate skills

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — grounds the audit in shared quality standards; DRY is a first-class principle there
- [`meta/reuse-before-create`](../../meta/reuse-before-create/SKILL.md) — this skill is the audit version of that meta rule; you identify where the rule was violated
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — enforces grep-first, sample-based reading, and the 30-file hard cap that make this audit tractable

## Token discipline (specific)

**Grep before you read. Always. No exceptions.**

The entire efficiency of this audit depends on never opening a file until grep has confirmed it's part of a pattern worth investigating.

**Per-category grep recipes:**

UI components — find near-identical JSX and repeated className strings:
```bash
# Repeated className patterns (Tailwind)
grep -rn "flex items-center" src/components --include="*.tsx" | head -40
grep -rn "className=\"" src/components --include="*.tsx" | sort | uniq -d | head -20
# Wrapper-only components (one JSX child, props passthrough)
grep -rn "return <" src/components --include="*.tsx" | grep -v "//" | head -30
```

Logic — find duplicate verb-prefixed helpers:
```bash
grep -rn "^export.*function \(format\|parse\|validate\|is\|has\|to\|from\)" src --include="*.ts" | sort
grep -rn "export const format\|export const parse\|export const validate" src --include="*.ts" | sort
grep -rn "debounce\|throttle\|chunk\|groupBy\|sleep\|retry" src --include="*.ts" | grep -v node_modules
```

Types — find similar shape declarations:
```bash
grep -rn "^interface \|^type " src --include="*.ts" --include="*.tsx" | sort | head -60
grep -rn "email.*string\|password.*string\|userId.*string" src --include="*.ts" | head -30
grep -rn "| 'active' | 'inactive'\|| 'pending' | 'approved'" src --include="*.ts" | head -20
```

Schemas — find re-declared validation objects:
```bash
grep -rn "z\.object\|Yup\.object\|v\.object" src --include="*.ts" --include="*.tsx" | sort
grep -rn "z\.string.*email\|z\.string.*min" src --include="*.ts" | sort | uniq -d
grep -rn "email.*required\|password.*min" src --include="*.ts" | head -20
```

Styles — find repeated Tailwind patterns and magic values:
```bash
grep -rn "flex items-center justify-between" src --include="*.tsx" | wc -l
grep -rn "gap-4\|gap-6\|gap-8" src --include="*.tsx" | sort | head -30
grep -rn "#[0-9a-fA-F]\{6\}\|rgb(" src --include="*.css" --include="*.tsx" | sort | uniq -d
grep -rn "@keyframes" src --include="*.css" | sort
```

Data layer — find repeated query/mutation patterns:
```bash
grep -rn "useQuery\|useMutation\|fetch\|axios\.get" src --include="*.ts" --include="*.tsx" | sort
grep -rn "invalidateQueries\|queryClient" src --include="*.ts" --include="*.tsx" | sort
grep -rn "SELECT.*FROM users\|JOIN.*profiles" src --include="*.ts" | sort
```

**Sampling rule:** Read 2-3 files per cluster to confirm the pattern. The pattern repeats — you don't need all N members.

**Hard cap:** Do not open more than 30 files total for a single audit. If you reach 30, the patterns are clear enough. Write the report.

**Do not read:** tests of the duplicated code (unless test-duplication is the stated subject), `node_modules/`, `dist/`, `.next/`, build artifacts.

## Process

**Step 1 — Scope clarification**
Confirm what you're auditing: full repo, a specific directory, or specific duplication categories. If the request is ambiguous, default to full repo but note it in the Scope section of your output. Record the root path.

**Step 2 — Grep pass (one per category)**
Run the grep recipes above for each of the six categories. Don't read files yet. Collect candidate clusters: groups of file paths that look like they share a pattern. Log the commands you ran so the report is reproducible.

**Step 3 — Filter noise**
Eliminate false positives from grep output: identical imports, test fixtures, generated code, intentional variants. What remains are genuine candidate clusters.

**Step 4 — Cluster formation**
Group related occurrences into named clusters. A cluster = one finding, not one file. Name each cluster with a one-line description of the pattern (e.g. "Currency formatter reimplemented per feature").

**Step 5 — Read to confirm**
For each cluster, open 2-3 representative files. Confirm the duplication is real. Note any differences between variants (behavioral drift is a severity escalator). Stop reading when the pattern is confirmed.

**Step 6 — Classify**

Severity:
- **Critical** — variants have drifted and now behave differently; bugs are possible or already present
- **High** — changes require editing N places; active development velocity hit
- **Medium** — maintainability issue; not an active bug driver
- **Low** — cosmetic / cleanup opportunity

Consolidation effort:
- **Trivial** — the unified version already exists; replace with import
- **Small** — extract a shared util or component, ≤2h
- **Medium** — parameterize and migrate consumers, ½–1 day
- **Large** — non-trivial design needed (new prop API, composition shape, shared context)

**Step 7 — Propose consolidation**
For each cluster, propose a concrete extraction: name the file where the unified version should live, the function/component signature, and how existing consumers change. Be specific. "Extract to a shared util" without naming the API is not a proposal.

**Step 8 — Write report**
Follow the output format below exactly. Include a "What's already good" section — calibration matters for authors and reviewers.

**Step 9 — Hand off**
State explicitly that Medium and Large clusters should be handed to `architecture/refactor-planner` for execution planning.

## Output format

```
## Scope
<Repo root or directory audited. Categories included. Date of audit.>

## Commands run
<List of grep commands executed so the audit is reproducible.>

## Summary
- Total clusters found: N
- By severity: Critical X / High Y / Medium Z / Low W
- By category: UI X / Logic Y / Type Z / Schema W / Style V / Data U
- Highest-leverage cluster: <one-line description>

## Findings

### Cluster N: <one-line description>

**Severity:** Critical | High | Medium | Low
**Consolidation effort:** Trivial | Small | Medium | Large
**Pattern type:** UI | Logic | Type | Schema | Style | Data layer

**Locations:**
- `path/to/file1.ts:42` — variant A (one-line note on what's different, if anything)
- `path/to/file2.ts:88` — variant B
- `path/to/file3.ts:15` — variant C
- ... (N total occurrences)

**Differences (if any):**
- Variant A uses X; variant B uses Y; variant C matches A but adds Z

**Proposed consolidation:**
- Extract `functionName(param1, param2?)` to `src/lib/targetFile.ts`. Callers in files A, B, C all reduce to the same call with `param2` defaulting to the current hardcoded value.

**Justification:**
- <One line: why N → 1 is clearly better, not just smaller.>

**Risk / blockers:**
- <Any reason this is harder than it looks: circular imports, consumers in separate packages, etc.>

---

## What's already good
<1-3 areas where DRY discipline is visibly maintained. Calibrates the findings and acknowledges existing discipline.>

## Recommended next steps
- Trivial and Small clusters → batch into one cleanup PR; no planning needed
- Medium and Large clusters → hand to `architecture/refactor-planner` for execution planning
- Re-audit after cleanup to verify no new instances emerged
- Consider running `jscpd` or `cpd` (see Notes) as a complementary automated pass
```

## Anti-patterns

- ❌ Reading every file in the codebase before reporting — grep first, sample to confirm, then report
- ❌ Recommending "extract to a shared util" without specifying the name, location, and signature of the extracted thing
- ❌ Treating two functions with the same name but different behavior as duplicates — that's a naming bug, not duplication
- ❌ Recommending consolidation that erases meaningful differences (UserCard vs AdminCard with intentionally different rendering are not a cluster)
- ❌ Severity inflation — calling everything Critical for emphasis dilutes the signal and destroys trust in the report
- ❌ Listing each file occurrence as a separate finding instead of clustering — 12 files sharing one pattern = 1 finding
- ❌ Recommending a new abstraction layer ("create a generic FormFactory") for 3 instances of duplication — usually overkill; Small effort is usually right
- ❌ Auditing the whole repo when a specific directory was scoped — respect the scope boundary
- ❌ Skipping the "What's already good" section — reviewers and authors need calibration, not just a problem list
- ❌ Missing the consolidation justification — N → 1 must be clearly better, not just smaller; sometimes duplication is the right call
- ❌ Confusing similar with duplicate — intentional variants with diverging feature requirements are a design choice, not a defect
- ❌ Opening tests to understand duplicated production code unless test duplication itself is the audit subject
- ❌ Hitting the 30-file cap and continuing anyway — if patterns aren't clear by 30 files, scope the audit down

## Notes

**Execution is not your job.** This skill outputs a report. Consolidation planning belongs to `architecture/refactor-planner`. Don't propose implementation timelines or write code.

**When NOT to consolidate:**
- The two implementations are about to diverge for legitimate reasons (different product directions)
- The shared abstraction would introduce a circular import or cross-package coupling that's worse than the duplication
- The duplication is in a soon-to-be-deleted feature
- The proposed abstraction would be called in only 2 places — premature abstraction risk is real below ~3 consumers
- The "duplicate" logic is intentionally duplicated to keep modules independent (e.g., two microservices that must not share a lib)

**Automated tools that complement this skill:**
- `jscpd` (JavaScript Copy-Paste Detector) — finds textual/token-level copy-paste across files that grep misses; run with `jscpd src/ --min-lines 5 --reporters json`
- `cpd` (PMD Copy-Paste Detector) — language-agnostic alternative; useful when the codebase includes non-JS files
- These tools catch verbatim copies; this skill finds semantic duplication (same logic, different variable names) — they're complementary, not substitutes

**Calibration note:** A codebase with zero duplication clusters is a red flag, not a goal. Some duplication is deliberate. Your job is to surface the clusters where consolidation delivers clear value, not to eliminate all similarity.
