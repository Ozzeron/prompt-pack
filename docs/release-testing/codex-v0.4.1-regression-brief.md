# Codex Regression Brief - v0.4.1 release testing

> **This is the manual regression brief used during the v0.4.1 Codex-target validation.**
> It is intentionally environment-specific: Windows, PowerShell, Codex CLI `0.130.0-alpha.5`.
> Use it as release-testing documentation or adapt it for your local Codex CLI version.
> It is **not part of automated CI.**
>
> See `CHANGELOG.md` for the v0.4.1 fixes this brief surfaced (composed flows, profile-aware
> cross-skill links, routing disambiguation).
>
> Deterministic checks landed in CI with v0.5.0: T1 = `npm run lint`, T2 = the dry-run smoke
> jobs, T3/T8/T9/T10 = tests 6-8 in `scripts/test-install-content.sh` plus the `codex` entry in
> the cross-shell parity job.
> LLM-based checks (T4, T5, T6) intentionally remain manual because they require network access
> to `api.openai.com` and produce non-deterministic results.

---

# prompt-pack v0.4.0 â€” Codex Regression Test Brief (v10)

**Repo:** https://github.com/Ozzeron/prompt-pack
**Target:** Codex CLI only (Windows / PowerShell 5.1+ or PowerShell 7)
**Codex CLI version tested:** 0.130.0-alpha.5+ (any version with `codex exec` and `--ephemeral`)
**Mode:** Do not modify the prompt-pack repo. Writes are allowed only in temp test dirs.
**Goal:** Validate the prompt-pack v0.4.0 `codex` target end-to-end: installer, layout, AGENTS.md content, skill discovery, routing, and the known cross-skill links bug.

This brief is designed to be **executed autonomously by Codex**. Findings only â€” no fixes.

---

## Purpose â€” why each test exists

prompt-pack is a curated AI coding discipline pack: 23 skills + multi-target installer + linter + routing layer. This brief proves the **`codex` target** ships a working install end-to-end.

| Test | What it proves | What a FAIL means |
|---|---|---|
| T1 | Source format invariants hold (frontmatter, sections, profile references, linter cross-checks). | Source repo is broken; ship-blocker. |
| T2 | Installer dry-run output is parseable and per-profile skill set matches expectations. | Installer broke its output format or filtered skills wrong; ship-blocker. |
| T3 | Real install lands all 23 skills, foundation `openai.yaml` policy files, and a budget-fitting AGENTS.md. | Installer regression; ship-blocker. |
| T4 | Static AGENTS.md visibility covers all 23 installed skills; representative `$skill` invocations prove runtime loading. | A skill is missing from AGENTS.md entirely (static), or a representative skill body doesn't load (runtime). Per-skill blocker for static; runtime extrapolated. |
| T5 | task-router (via AGENTS.md) maps natural-language intents to the right specialist and asks clarifying questions on ambiguity. | Routing logic wrong or agent over-confident; severity depends on which intent failed. |
| T6 | Composed flow (`full PR review` â†’ code-review + security-review) is encoded in AGENTS.md and reached by the agent. | Missing static composed-flow row is a GAP (documented limitation) unless basic routing breaks entirely â€” see the decision matrix in T6. |
| T8 | Cross-skill `../<name>/SKILL.md` links resolve within each installed profile. | Quantifies the known broken-links bug; expected non-zero on partial profiles. Not a release gate. |
| T9 | AGENTS.md is UTF-8 without BOM and preserves multilingual aliases (Cyrillic, Ukrainian, etc.). | Encoding regression â€” prior smoke test caught mojibake at install time. Ship-blocker. |
| T10 | Every installed skill is *listed* somewhere in AGENTS.md (as `$skill-name` or by bare name). Task-facing skills have routing rows; foundation/inherit-only skills may be listed without a dedicated NL route. | A skill is completely absent from AGENTS.md = blocker. Missing task-facing routing row = polish (case-by-case). Foundation skill without a route is expected. |

**T7 (frontmatter `inherit-only` invariant) is intentionally NOT in this brief** â€” `scripts/lint-skills.mjs` already enforces `triggers: [inherit-only] must be sole trigger` strictly (`if (hasInheritOnly && fm.triggers.length !== 1) failures.push(...)`). T1 covers it. A separate test would be 100% duplicate of T1.

**Reporting rule:** If a surface check fails but the property still holds (e.g. a regex didn't match but the file is correct), report PASS with `notes:` caveat. Do not silently downgrade.

---

## Setup

### Network / sandbox requirements

Codex CLI (`codex exec`) opens a websocket to `api.openai.com`. Sandboxed environments without outbound network access will fail T4â€“T6 with errors like `os error 10013` (Windows access denied) before any prompt runs.

- If running in a sandbox: rerun T4â€“T6 with elevated/network permissions, OR move them outside the sandbox.
- T1, T2, T3, T8, T9, T10 are pure file/process checks and do not need network.

### Pre-flight: brief file encoding self-check

Before running, verify this brief file itself is clean UTF-8 (not mojibake from a bad save):

```powershell
$briefPath = "<path-to-this-brief.md>"
$bytes = [System.IO.File]::ReadAllBytes($briefPath)
$text = [System.Text.Encoding]::UTF8.GetString($bytes)
if ($text -match 'Ã[Â¿Ã‘ÂµÂ²Â¶Â½]|Ã¢â‚¬|Ã¢â€ ') {
  Write-Host "WARNING: brief file appears mojibaked. Re-save as UTF-8 before running." -ForegroundColor Red
} else {
  Write-Host "Brief encoding: OK" -ForegroundColor Green
}
```

Note: PowerShell **console** may render Cyrillic strings in this brief as `?????` if the console codepage isn't UTF-8. That's a rendering issue, not a file content issue â€” the bytes are correct. The check above reads bytes directly.

### Setup commands

```powershell
# Always clone into a fresh temp directory â€” never touch the user's working copy.
# This honours the "Do not modify the prompt-pack repo" rule even if a dev clone exists.
$repoDir = "$env:TEMP\prompt-pack-v040-$(Get-Date -Format yyyyMMdd-HHmmss-fff)"
git clone https://github.com/Ozzeron/prompt-pack.git $repoDir
Set-Location $repoDir
# Pin to v0.4.0 tag for a true regression baseline. To test current main,
# skip the checkout and note it in "Run metadata".
git checkout v0.4.0
# Use npm ci if lockfile exists (reproducible), fallback to npm install.
if (Test-Path package-lock.json) { npm ci } else { npm install }
```

`$repoDir` is the canonical repo path for the rest of this brief. Keep it set throughout the run.

Record runtime metadata for the report header:

```powershell
codex --version
codex exec --help | Select-Object -First 40
$PSVersionTable.PSVersion
(Get-Item .).Name
git -C $repoDir rev-parse HEAD
```

Helper function â€” use throughout:

```powershell
function New-TestDir {
  $dir = "$env:TEMP\pp-test-$(Get-Date -Format yyyyMMdd-HHmmss-fff)"
  New-Item -ItemType Directory $dir | Out-Null
  Set-Location $dir
  git init | Out-Null
  return $dir
}
```

### Codex CLI command template (canonical for T4â€“T6)

This brief targets the locally tested Windows Codex CLI version: **`codex-cli 0.130.0-alpha.5`**.

Flag placement differs across Codex CLI versions and docs/help output may be misleading. **For this version, `--ask-for-approval`, `--sandbox`, and `--cd` must be placed BEFORE the `exec` subcommand.** `--ephemeral` and `--json` remain `exec` options AFTER the subcommand.

This was confirmed empirically: putting approval/sandbox/cd after `exec` produces `error: unexpected argument '--ask-for-approval' found` on this version.

Canonical:

```powershell
codex --ask-for-approval never --sandbox read-only --cd "$testDir" exec --ephemeral '<prompt>'
```

Short form (same flags):

```powershell
codex -a never -s read-only -C "$testDir" exec --ephemeral '<prompt>'
```

JSONL form (for machine-parsable output in batch loops):

```powershell
codex -a never -s read-only -C "$testDir" exec --ephemeral --json '<prompt>'
```

**Pre-flight check before running T4â€“T6:**

```powershell
codex --version
codex --help
codex exec --help
# Smoke the chosen syntax with a trivial prompt:
codex -a never -s read-only -C "$testDir" exec --ephemeral 'Respond with OK only.'
```

If the smoke fails with `unexpected argument`, try the inverse order (flags after `exec`) and note the deviation in "Run metadata".

**PowerShell quoting:**
- Use **single quotes** around prompts containing `$skill-name`. PowerShell doesn't expand `$variable` inside single quotes, so the literal `$code-review` passes through. Double quotes would expand `$code` to empty.
- To include a literal single quote inside a single-quoted prompt, **double it**: `'Don''t execute the task'`.

**Flag meanings:**
- `--ephemeral`: no session rollout file written to disk â€” test runs leave no artifacts.
- `-a never -s read-only`: safe non-interactive combo â€” Codex reads but never modifies, no approval prompts.
- `--json`: JSONL events to stdout, useful for parsing skill-selection programmatically.

---

## T1 â€” Linter

```powershell
Set-Location $repoDir
npm run lint
```

**Pass criteria:** Exit code 0. Linter validates:
- Per-skill: frontmatter schema, description length, section order, internal link resolution, leakage terms, code-creating skill inheritance, **`triggers: [inherit-only]` is sole when present**.
- Cross-checks: installer profile parity, README profile counts, task-router active table references.

**Report:** PASS / FAIL. On FAIL, paste the first 15 lines of stderr.

---

## T2 â€” Installer dry-run output: per-profile counts

The `codex` target writes one directory per skill at `.agents/skills/<name>/` plus a project `AGENTS.md` and `agents/openai.yaml` policy files for the four foundation skills.

```powershell
$profiles = @(
  @{ name = "minimal";   expected = 4  },
  @{ name = "nextjs";    expected = 10 },
  @{ name = "backend";   expected = 13 },
  @{ name = "supabase";  expected = 14 },
  @{ name = "fullstack"; expected = 21 },
  @{ name = "all";       expected = 23 }
)

$rows = @()
foreach ($p in $profiles) {
  $tmp = New-TestDir
  # Capture stdout (1), stderr (2), AND Information stream (6) where Write-Host lives.
  # PowerShell 5.1 does NOT capture Write-Host through `& ... 2>&1` alone â€” stream 6
  # is separate and must be explicitly merged or the count will always be 0.
  $output = & "$repoDir\install.ps1" -Target codex -Profile $p.name -Path $tmp -DryRun -Force *>&1

  # Count distinct .agents\skills\<leaf-name> directory lines.
  # Match both backslash and forward slash; require leaf at end of line (excludes sub-paths).
  $skillWrites = ($output | Select-String '\.agents[\\/]skills[\\/][^\\/\s]+$' |
                  ForEach-Object { ($_ -split '[\\/]')[-1].Trim() } |
                  Sort-Object -Unique).Count

  # Fallback: parse "Skills:  N" summary line if regex finds 0
  if ($skillWrites -eq 0) {
    $summaryLine = $output | Select-String 'Skills:\s+(\d+)'
    if ($summaryLine) { $skillWrites = [int]($summaryLine.Matches[0].Groups[1].Value) }
  }

  $pass = if ($skillWrites -eq $p.expected) { "PASS" } else { "FAIL" }
  $rows += [pscustomobject]@{ profile = $p.name; expected = $p.expected; counted = $skillWrites; status = $pass }
}
$rows | Format-Table
```

**Pass criteria:** every profile counted == expected.

**Diagnostic:** If all show 0, check two things:
1. **Stream capture.** PowerShell 5.1 does not capture `Write-Host` (stream 6) through `2>&1` alone. The `*>&1` redirect above merges all streams. If you see 0 with `*>&1`, the regex is wrong.
2. **Installer format.** Run one profile without `-DryRun`, paste actual format into the report, and adjust regex.

**Note on `codex` target:** Unlike `cursor` and `agents` targets, `codex` does NOT filter `meta/task-router`. The router stays. So `fullstack` includes it (21 skills, matches installer profile definition).

**Report:** Profile | expected | counted | status table. On FAIL, attach dry-run output for the failing profile.

---

## T3 â€” Real install (`all` profile) + layout verification

```powershell
$testDir = New-TestDir
& "$repoDir\install.ps1" -Target codex -Profile all -Path $testDir -Force | Out-Null

# 1) Skill count â€” direct children of .agents\skills (not recursive)
$allSkillDirs = Get-ChildItem -Directory "$testDir\.agents\skills"
$skillCount = $allSkillDirs.Count
Write-Host "Skills installed: $skillCount (expect 23) â€” $(if ($skillCount -eq 23) {'PASS'} else {'FAIL'})"

# 2) Every skill dir has a SKILL.md
$missing = $allSkillDirs | Where-Object { -not (Test-Path (Join-Path $_.FullName 'SKILL.md')) }
Write-Host "Skill dirs missing SKILL.md: $($missing.Count) (expect 0) â€” $(if ($missing.Count -eq 0) {'PASS'} else {'FAIL'})"

# 3) AGENTS.md exists and fits Codex's 32 KiB project_doc_max_bytes budget
$agentsPath = "$testDir\AGENTS.md"
if (Test-Path $agentsPath) {
  $size = (Get-Item $agentsPath).Length
  Write-Host "AGENTS.md size: $size bytes (expect < 32768) â€” $(if ($size -lt 32768) {'PASS'} else {'FAIL'})"
} else {
  Write-Host "AGENTS.md: MISSING â€” FAIL"
}

# 4) Foundation skills: agents/openai.yaml with allow_implicit_invocation: false
#    This is Codex's official runtime mechanism for explicit-only policy.
#    Confirmed in Codex docs: developers.openai.com/codex/skills
@("engineering-principles","reuse-before-create","token-discipline","task-router") | ForEach-Object {
  $yamlPath = "$testDir\.agents\skills\$_\agents\openai.yaml"
  $exists   = Test-Path $yamlPath
  $ok       = $false
  if ($exists) {
    $content = Get-Content $yamlPath -Raw
    # Must contain policy block with allow_implicit_invocation: false
    $ok = ($content -match '(?ms)policy:\s*\n\s*allow_implicit_invocation:\s*false') -or
          ($content -match 'allow_implicit_invocation:\s*false')
  }
  $status = if ($exists -and $ok) { 'PASS' } elseif ($exists) { 'FAIL (wrong content)' } else { 'FAIL (missing)' }
  Write-Host "$_ openai.yaml: $status"
}
```

**Pass criteria:** all four numbered checks PASS.

**Note:** Source frontmatter `triggers: [inherit-only]` invariant is NOT re-checked here. Linter (T1) enforces it strictly on source; the installer copies SKILL.md verbatim. A separate runtime frontmatter check would be a 100% T1 duplicate.

**Report:** Each numbered check â€” expected vs actual, PASS/FAIL. Keep `$testDir` for T4â€“T6 and T9/T10.

---

## T4 â€” Skill discovery: static + LLM smoke

Two-phase check. Phase A is fast and deterministic; Phase B is the truth test.

### Phase A â€” Static: every installed skill is mentioned in AGENTS.md

This check confirms *visibility* (some mention exists). T10 separately tightens the criterion to `$skill-name` references for routing completeness.

```powershell
$agents = Get-Content "$testDir\AGENTS.md" -Raw
$installedSkills = (Get-ChildItem -Directory "$testDir\.agents\skills").Name

$missingFromAgents = @()
foreach ($skill in $installedSkills) {
  # AGENTS.md should reference the skill either as $skill-name or as the bare name
  # in the routing table. Be permissive but require *some* mention.
  if ($agents -notmatch [regex]::Escape($skill)) {
    $missingFromAgents += $skill
  }
}

Write-Host "Skills missing from AGENTS.md: $($missingFromAgents.Count) (expect 0)"
if ($missingFromAgents.Count -gt 0) {
  $missingFromAgents | ForEach-Object { Write-Host "  $_" }
}
```

**Phase A pass:** zero skills missing from AGENTS.md.

### Phase B â€” LLM smoke on 5 representative skills

Running explicit `$skill-name` invocation on **all 23** is overkill: ~3-5 minutes of LLM calls when Phase A already proves discovery. Run 5 representative skills across categories instead. If Phase A passes and these 5 work, the rest are *likely* covered â€” but this remains a representative runtime smoke, not formal proof for all 23 (see honest caveat below).

Representative set:
- `$code-review` (review category)
- `$backend-api` (architecture category)
- `$handoff` (delivery category)
- `$ui-designer` (interface category)
- `$docker` (infra category)

For each:

```powershell
codex -a never -s read-only -C "$testDir" exec --ephemeral 'Use $<skill-name>. Smoke only. Do not run code or inspect files. Answer in exactly 3 lines. Line 1: available yes or available no. Line 2: structured-output yes or structured-output no. Line 3: primary-artifact followed by one short noun phrase.'
```

**Note on prompt quoting:** Avoid embedded double quotes in PowerShell single-quoted prompts â€” native argument parsing on Windows can mangle them. Use plain phrasing instead of `"available: yes"` style.

**Note on coverage:** If these 5 representative skills pass, it *supports* runtime discovery across the pack but does not formally prove all 23 explicit invocations work. Phase A's static check is the stronger signal for the remaining 18.

**Honest caveat on Phase B:** This is a runtime *self-report* smoke. The agent could in principle answer `available: yes` without the skill body actually loading. Phase A (static AGENTS.md presence) is what proves discoverability deterministically; Phase B catches the case where AGENTS.md mentions a skill but the body itself is unreachable.

### Optional enhancement â€” trace-level proof via `--json`

If `codex exec --json` on the installed version emits skill-load events (format: JSONL events to stdout), you can replace Phase B's self-report with a trace check:

```powershell
$json = codex -a never -s read-only -C "$testDir" exec --ephemeral --json 'Use $code-review. Respond with OK only.' 2>&1
# Inspect JSONL events for a skill-load event referencing code-review's SKILL.md path.
# Exact event name varies by Codex version â€” check `codex exec --help --json` or one trial run.
$json | Select-String -Pattern 'code-review|SKILL\.md|skill.*load|skill.*invoke' | Select-Object -First 10
```

If the trace format isn't stable in 0.130.0-alpha.5, skip the enhancement and rely on Phase A + self-report Phase B. Note the choice in the report.

**Phase B pass per skill:**
- Line 1 says `available: yes`.
- Line 3 is a short noun phrase (not prose, not "n/a").

**Special case for foundation skills:** `engineering-principles`, `reuse-before-create`, `token-discipline`, `task-router` are `inherit-only` â€” Codex won't implicitly invoke them, but explicit `$<name>` MUST still work. Not in the representative 5 by design (they're foundation/orchestration, not workflow). If you want a foundation smoke, add `$engineering-principles` as a 6th test â€” expected `available: yes` on explicit call.

**Report:**

| skill | static (Phase A) | LLM (Phase B) | notes |
|---|---|---|---|
| code-review | yes | available + shape match | |
| ... | | | |

Flag any FAIL.

---

## T5 â€” task-router: 5 ambiguous-aware intents

Reuse `$testDir`. For each intent, run:

```powershell
codex -a never -s read-only -C "$testDir" exec --ephemeral '<intent>. Do NOT execute the task. State only: which skill(s) you would use, and why, one short line per skill. If genuinely ambiguous, ask exactly one clarifying question instead. Do not produce any other output.'
```

Intents (down from 8 â€” these 5 cover the high-value routing decisions):

| # | Intent | Expected | PASS criteria |
|---|---|---|---|
| 1 | "Build a new REST endpoint for user settings" | `$backend-api` | Names `backend-api` as lead. |
| 2 | "Review this code" (no diff explicitly named) | Clarifying question OR a `*-audit` skill | Either asks "where's the diff?" / asks scope, OR routes to `repo-audit`/`frontend-audit`. Routing directly to `code-review` here = soft FAIL (wrong scope). |
| 3 | "Run a full PR review" | `$code-review` then `$security-review` | Names both, in order. (T6 covers the static AGENTS.md side.) |
| 4 | "Fix bug" (no error signal provided) | Clarifying question asking for the failure signal | Any clarifying question. Routing to `$debugger` without first asking = soft FAIL. |
| 5 | "Wrap up this task" | `$handoff` | Names `handoff`. |

**Why these 5:** they cover the routing-edge cases that empirical testing showed agents most often miss (review-without-diff, composed PR review, bug-without-signal) plus happy-path controls (clear backend intent, handoff).

**Report:** Compact table â€” `# | stated skill(s) | clarifying? | correct (yes/no/soft-fail) | notes`. Quote only the routing decision line.

---

## T6 â€” Composed flow: AGENTS.md bridge + LLM check

Composed flows (e.g. `code-review â†’ security-review`) are the only multi-skill flow the README markets. If the AGENTS.md bridge doesn't encode them, the natural-language "full PR review" intent won't reach both skills.

### Step 1 â€” Static

```powershell
$agents = Get-Content "$testDir\AGENTS.md" -Raw

# A. Bare mentions (lower bar)
Write-Host "AGENTS.md mentions code-review: $([bool]($agents -match 'code-review'))"
Write-Host "AGENTS.md mentions security-review: $([bool]($agents -match 'security-review'))"

# B. Composed-flow line (higher bar)
# Look for a single line that pairs both skills â€” that's a real composed-flow row.
$composedLine = $agents -split "`r?`n" |
  Where-Object { ($_ -match 'code-review') -and ($_ -match 'security-review') } |
  Select-Object -First 1
$hasComposed = [bool]$composedLine
Write-Host "AGENTS.md has composed-flow line pairing both: $hasComposed"
if ($composedLine) { Write-Host "  -> $composedLine" }
```

### Step 2 â€” LLM

```powershell
codex -a never -s read-only -C "$testDir" exec --ephemeral 'I need a full PR review. Do NOT execute. State only: which skills would you invoke and in what order? One short line per skill.'
```

**Decision matrix:**

| Static B | LLM names both | Verdict |
|---|---|---|
| true | true | **PASS** |
| true | only one | **PARTIAL** â€” bridge encodes it but agent missed it. Quote LLM response. |
| false | true | **PASS with caveat** â€” agent inferred without explicit row. Lucky. |
| false | only one | **GAP** â€” composed flow not in bridge AND not inferred. Documented limitation, not regression. |
| any | names neither | **FAIL** â€” basic routing broken. |

**Report:** Static A + B results, LLM response line, verdict from matrix.

---

## T8 â€” Cross-skill link integrity across all 6 profiles

Source SKILL.md files reference siblings as `[label](../<name>/SKILL.md)`. After install into flat `.agents/skills/<leaf>/`, the link resolves to `../<leaf>/SKILL.md`. If that leaf isn't installed (because it's outside the chosen profile), the link is broken.

Each profile installs into its **own fresh temp dir** â€” installer does not clean between profiles.

```powershell
$profiles = @("minimal","nextjs","backend","supabase","fullstack","all")
$summary = @()

foreach ($profileName in $profiles) {
  $dir = New-TestDir
  & "$repoDir\install.ps1" -Target codex -Profile $profileName -Path $dir -Force | Out-Null

  $installedSkills = (Get-ChildItem -Directory "$dir\.agents\skills").Name
  $broken = @()

  Get-ChildItem -Recurse -Filter "SKILL.md" "$dir\.agents\skills" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    foreach ($m in [regex]::Matches($content, '\]\(\.\./([^/]+)/SKILL\.md\)')) {
      $target = $m.Groups[1].Value
      if ($installedSkills -notcontains $target) {
        $broken += [pscustomobject]@{ source = $_.Directory.Name; target = $target }
      }
    }
  }

  $summary += [pscustomobject]@{
    profile     = $profileName
    brokenCount = $broken.Count
    topSources  = ($broken | Group-Object source | Sort-Object Count -Descending |
                   Select-Object -First 3 |
                   ForEach-Object { "$($_.Name)($($_.Count))" }) -join ', '
  }

  Write-Host "`nProfile: $profileName | broken=$($broken.Count)"
  $broken | Select-Object -First 5 | ForEach-Object { Write-Host "  $($_.source) -> $($_.target)" }
  if ($broken.Count -gt 5) { Write-Host "  ... and $($broken.Count - 5) more" }
}

Write-Host "`n=== Summary ==="
$summary | Format-Table
```

**Pass criteria:**
- `fullstack` and `all`: **0 broken links** (PASS).
- `minimal`, `nextjs`, `backend`, `supabase`: **non-zero expected** (known issue; record exact counts and top-3 source skills).

**Baseline broken-link inventory (v0.4.0 prior run):** record deviations from this baseline as new regressions:

| Profile | Expected broken | Specific links |
|---|---|---|
| minimal | 1 | `reuse-before-create -> duplication-audit` |
| nextjs | 1 | `reuse-before-create -> duplication-audit` |
| backend | 2 | `database-migrations -> postgres-supabase`, `reuse-before-create -> duplication-audit` |
| supabase | 1 | `reuse-before-create -> duplication-audit` |
| fullstack | 0 | â€” |
| all | 0 | â€” |

If actual count exceeds baseline = new broken links introduced (regression). If below = installer fixed something.

**Report:** Summary table â€” profile | brokenCount | topSources | PASS/KNOWN-ISSUE.

---

## T9 â€” AGENTS.md encoding integrity

Prior smoke testing caught mojibake in AGENTS.md when PowerShell rendered it to console, even though the file itself was correct UTF-8. The check below validates the **file** bytes, not console rendering.

```powershell
$agentsPath = "$testDir\AGENTS.md"

# 1) File exists
if (-not (Test-Path $agentsPath)) {
  Write-Host "AGENTS.md: MISSING â€” FAIL"
  return
}

# 2) UTF-8 without BOM
$bytes = [System.IO.File]::ReadAllBytes($agentsPath)
$hasBOM = ($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)
Write-Host "AGENTS.md UTF-8 BOM: $hasBOM (expect False) â€” $(if (-not $hasBOM) {'PASS'} else {'FAIL'})"

# 3) Valid UTF-8 â€” strict decoder (throws on invalid bytes, no replacement fallback).
#    Default UTF8.GetString silently replaces bad bytes with U+FFFD and returns success,
#    which would give a false PASS on a corrupted file.
try {
  $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
  $text = $utf8Strict.GetString($bytes)
  Write-Host "AGENTS.md UTF-8 decode (strict): OK â€” PASS"
} catch {
  Write-Host "AGENTS.md UTF-8 decode (strict): FAIL â€” $_"
  return
}

# 4) Multilingual aliases survive (Cyrillic + Ukrainian sample words from prior smoke)
$samples = @("Ð¿Ñ€Ð¾Ñ€ÐµÐ²ÑŒÑŽÐ¹", "Ñ€ÐµÐ²ÑŒÑŽ", "Ð¿Ñ€Ð¾Ð²ÐµÑ€ÑŒ", "Ð¿ÐµÑ€ÐµÐ²Ñ–Ñ€")
$missing = @()
foreach ($s in $samples) {
  if ($text -notmatch [regex]::Escape($s)) { $missing += $s }
}
if ($missing.Count -eq 0) {
  Write-Host "Multilingual aliases preserved: PASS"
} else {
  Write-Host "Multilingual aliases missing: $($missing -join ', ') â€” FAIL"
}
```

**Pass criteria:** file exists, no BOM, valid UTF-8 decode, all 4 sample aliases present.

**Note:** If aliases changed in v0.4.x, update the `$samples` array to current strings from `prompts/meta/task-router/SKILL.md` or the install.ps1 template.

**Report:** Each numbered check â€” PASS/FAIL.

---

## T10 â€” AGENTS.md installed-skill list completeness

Every installed skill should appear somewhere in AGENTS.md so Codex can find it. **Task-facing** skills should have a natural-language routing entry (a table row mapping intent to `$skill-name`). **Foundation / inherit-only / explicit-only** skills may be listed without a dedicated NL route â€” that's by design, not a bug.

T4 Phase A is the broader visibility check; T10 tightens it by distinguishing strong references (explicit `$skill-name`) from weak ones (bare name mentions).

```powershell
$agents = Get-Content "$testDir\AGENTS.md" -Raw
$installedSkills = (Get-ChildItem -Directory "$testDir\.agents\skills").Name

# Heuristic: a routing entry is a line that contains "$<skill-name>" or "-> $<skill-name>"
# OR a markdown-table row mentioning the skill in the routing context.
$results = @()
foreach ($skill in $installedSkills) {
  # Use literal Contains for the dollar-prefixed form â€” avoids regex anchor pitfalls
  # ($ is end-of-line in regex; -match "`$$skill" would never match literal $skill).
  $explicitRef = $agents.Contains("`$$skill")
  $bareMention = $agents -match [regex]::Escape($skill)

  $verdict = if ($explicitRef) { 'PASS' }
             elseif ($bareMention) { 'WEAK (only bare mention)' }
             else { 'FAIL (missing)' }

  $results += [pscustomobject]@{ skill = $skill; verdict = $verdict }
}

$results | Format-Table
$failCount = ($results | Where-Object { $_.verdict -like 'FAIL*' }).Count
$weakCount = ($results | Where-Object { $_.verdict -like 'WEAK*' }).Count
Write-Host "`nMissing routing entries: $failCount, weak: $weakCount"
```

**Pass criteria:**
- **0 hard FAIL:** every installed skill must appear in AGENTS.md *somehow* (explicit `$skill-name` OR bare mention). A skill completely absent = blocker.
- **WEAK is allowed:** foundation, inherit-only, and explicit-only skills may be listed without `$` prefix. Not a blocker.
- **Missing routing row for a task-facing skill:** polish/regression case-by-case, not auto-blocker.

**Note on `meta/task-router`:** The router itself may not be `$task-router`-invocable in AGENTS.md (it IS the router); any reference, even bare, is PASS for that one skill.

**Report:** Counts + table of FAIL/WEAK skills.

---

## Output Format

Produce a structured report with:

1. **Run metadata** â€” `codex --version`, OS, PowerShell version, repo commit SHA, brief timestamp.
2. **Summary table** â€” T1, T2, T3, T4, T5, T6, T8, T9, T10 â€” each PASS / FAIL / GAP / PARTIAL / KNOWN-ISSUE.
3. **Per-test details** â€” findings, exact counts, relevant output. T4 = compact two-column table only.
4. **Issues found** â€” numbered, severity: `blocking` / `polish` / `docs` / `gap`.
5. **Not tested** â€” anything skipped and why (e.g. `--ephemeral` flag missing, network blocked).

**Constraints:**
- T4: compact table only â€” no full LLM responses.
- T5/T6: quote only the routing decision line(s).
- Keep report under 250 lines total.
- If surface signal fails but property holds, call it out in `notes`. Do not silently re-classify.

---

## What this brief does NOT cover

- Other targets (cursor, agents, claude-code, openclaw, raw). This brief is Codex-only.
- `-Scope user` install (writes to `$HOME/.agents/skills/`). Out of scope to avoid polluting user-global state.
- macOS / Linux paths via `install.sh`. PowerShell only.
- Actual quality of skill output on real coding tasks. This is a regression test, not a quality eval.
- Cross-tool integration (Cursor + Codex coexistence in same repo). Documented separately in `docs/USAGE.md`.
