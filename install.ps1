<#
.SYNOPSIS
  Install prompt-pack skills into a project directory.

.DESCRIPTION
  Copies a curated set of skills from this prompt-pack into the right location
  for your AI tool of choice (Cursor, Claude Code, Codex CLI, OpenClaw, or as
  loose markdown for any other tool).

.PARAMETER Target
  Where to install. One of: cursor, cursor-foundation, cursor-rules, agents, claude-code, codex, codex-agents-md, openclaw, raw

  - cursor            : Cursor 2.4+ Skills-native install. Writes most skills
                        to `.cursor/skills/<name>/SKILL.md` (Agent Skills
                        format, picked up natively by Cursor 2.4+). The three
                        foundation rules (`engineering-principles`,
                        `reuse-before-create`, `token-discipline`) stay as
                        `.cursor/rules/*.mdc` with `alwaysApply: true` because
                        they need to be in scope on every turn and Skills are
                        agent-requested by default. `meta/task-router` is
                        filtered out — it duplicates Cursor's native skill
                        matcher.
  - cursor-foundation : Foundation-only Cursor install. Writes ONLY the three
                        foundation rules (engineering-principles,
                        reuse-before-create, token-discipline) to
                        `.cursor/rules/*.mdc` with `alwaysApply: true`. No
                        `.cursor/skills/` writes, so this target safely layers
                        on top of `-Target agents` (universal Skills install)
                        without producing duplicate Cursor skill roots.
  - cursor-rules      : Legacy Cursor target. Writes every skill to
                        `.cursor/rules/<name>.mdc` plus a `prompt-pack-router.mdc`
                        bridge. Use only for Cursor builds older than 2.4 or
                        if you prefer the rules-only flow.
  - agents            : Universal Agent Skills target. Writes each skill to
                        `.agents/skills/<name>/SKILL.md` only — no AGENTS.md
                        bridge. Works in Cursor 2.4+, Codex CLI, and GitHub
                        Copilot from one install. Prefer `-Target codex` if
                        you specifically want the Codex AGENTS.md router.
                        `meta/task-router` is filtered out — Codex / native
                        Skills matchers conflict with it. Do NOT also run
                        `-Target cursor` against the same repo (Cursor reads
                        both .agents/skills/ and .cursor/skills/, you'd get
                        duplicates). For Cursor users who want always-on
                        foundation rules, layer `-Target cursor-foundation`
                        instead.
  - codex             : Codex-native install. Writes each skill to
                        `.agents/skills/<name>/SKILL.md` (or to
                        `$HOME/.agents/skills/` when -Scope user) plus a
                        compact AGENTS.md router/bridge. This matches the
                        official Codex skills format with progressive
                        disclosure. Recommended for Codex CLI / IDE / app.
  - codex-agents-md   : Legacy single-file install. Concatenates all skills
                        into one AGENTS.md, capped at 32 KiB (Codex default
                        project_doc_max_bytes). Use only for hosts that do
                        not yet support `.agents/skills/`.

.PARAMETER Scope
  Codex install scope. One of: repo (default), user. Only used when
  -Target codex. `repo` writes to `<project>/.agents/skills/`; `user`
  writes to `$HOME/.agents/skills/` so every Codex session inherits the
  skills regardless of the working directory.

.PARAMETER Profile
  Which skill bundle to install. One of: minimal, nextjs, backend, supabase,
  fullstack, all. Default: minimal.

.PARAMETER Path
  Target project directory. Default: current directory.

.PARAMETER Skills
  Optional explicit list of skills (relative paths under prompts/). Overrides
  -Profile when provided.

.PARAMETER Force
  Overwrite existing files without prompting.

.PARAMETER List
  List available profiles and skills, do nothing else.

.EXAMPLE
  .\install.ps1 -Target cursor -Profile minimal

.EXAMPLE
  .\install.ps1 -Target codex -Profile supabase -Path ~\code\project-a

.EXAMPLE
  .\install.ps1 -Target cursor -Skills meta/engineering-principles, architecture/frontend-feature

.EXAMPLE
  .\install.ps1 -Target cursor -Profile minimal -DryRun

.NOTES
  Safety:
  - Without -Force, every overwrite is confirmed interactively.
  - With -Force, existing FILES are simply replaced; existing DIRECTORIES (only
    used by the openclaw target) are renamed to <name>.bak-<timestamp> before
    being replaced, never deleted outright.
  - -DryRun reports what would be written without making changes.
  - The script warns if the project already has agent-config files or if its
    git working tree is dirty.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('cursor', 'cursor-foundation', 'cursor-rules', 'agents', 'claude-code', 'codex', 'codex-agents-md', 'openclaw', 'raw')]
    [string]$Target,

    [Parameter(Mandatory = $false)]
    [ValidateSet('repo', 'user')]
    [string]$Scope = 'repo',

    [Parameter(Mandatory = $false)]
    [ValidateSet('minimal', 'nextjs', 'backend', 'supabase', 'fullstack', 'all')]
    [string]$Profile = 'minimal',

    [Parameter(Mandatory = $false)]
    [string]$Path = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string[]]$Skills,

    [switch]$Force,
    [switch]$NoBackup,
    [switch]$DryRun,
    [switch]$List
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Profile definitions
# ---------------------------------------------------------------------------

$Profiles = @{
    'minimal'   = @(
        'meta/engineering-principles',
        'meta/reuse-before-create',
        'meta/token-discipline',
        'delivery/handoff'
    )
    'nextjs'    = @(
        'meta/engineering-principles',
        'meta/reuse-before-create',
        'meta/token-discipline',
        'delivery/handoff',
        'architecture/frontend-feature',
        'interface/ui-designer',
        'review/code-review',
        'review/repo-audit',
        'review/debugger',
        'delivery/test-writer'
    )
    'backend'   = @(
        'meta/engineering-principles',
        'meta/reuse-before-create',
        'meta/token-discipline',
        'delivery/handoff',
        'architecture/backend-api',
        'architecture/database-schema',
        'architecture/database-migrations',
        'review/code-review',
        'review/repo-audit',
        'review/database-review',
        'review/security-review',
        'review/debugger',
        'delivery/test-writer'
    )
    'supabase'  = @(
        'meta/engineering-principles',
        'meta/reuse-before-create',
        'meta/token-discipline',
        'delivery/handoff',
        'architecture/backend-api',
        'architecture/database-schema',
        'architecture/database-migrations',
        'architecture/postgres-supabase',
        'review/code-review',
        'review/repo-audit',
        'review/database-review',
        'review/security-review',
        'review/debugger',
        'delivery/test-writer'
    )
    'fullstack' = @(
        'meta/engineering-principles',
        'meta/reuse-before-create',
        'meta/token-discipline',
        'meta/task-router',
        'architecture/backend-api',
        'architecture/frontend-feature',
        'architecture/database-schema',
        'architecture/database-migrations',
        'architecture/postgres-supabase',
        'architecture/refactor-planner',
        'interface/ui-designer',
        'review/code-review',
        'review/repo-audit',
        'review/frontend-audit',
        'review/database-review',
        'review/security-review',
        'review/duplication-audit',
        'review/debugger',
        'delivery/handoff',
        'delivery/test-writer',
        'delivery/doc-writer'
    )
    'all'       = $null  # filled at runtime by globbing prompts/
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Session-only flag: set the first time the user answers 'a' (yes to all)
# at a directory-replace prompt. Subsequent prompts in the same install
# behave as if -Force was passed.
$Script:ForceAll = $false

$ScriptRoot = $PSScriptRoot
$PromptsRoot = Join-Path $ScriptRoot 'prompts'

function Get-AllSkills {
    Get-ChildItem -Path $PromptsRoot -Recurse -Filter 'SKILL.md' | ForEach-Object {
        $relDir = $_.Directory.FullName.Substring($PromptsRoot.Length + 1).Replace('\', '/')
        $relDir
    } | Sort-Object
}

function Resolve-SkillList {
    param([string]$ProfileName, [string[]]$ExplicitSkills)

    if ($ExplicitSkills -and $ExplicitSkills.Count -gt 0) { return $ExplicitSkills }
    if ($ProfileName -eq 'all') { return Get-AllSkills }
    return $Profiles[$ProfileName]
}

function Show-List {
    Write-Host "`nAvailable profiles:" -ForegroundColor Cyan
    foreach ($k in $Profiles.Keys | Sort-Object) {
        $list = if ($k -eq 'all') { Get-AllSkills } else { $Profiles[$k] }
        Write-Host ("  {0,-10} {1} skills" -f $k, $list.Count) -ForegroundColor White
    }

    Write-Host "`nAvailable skills:" -ForegroundColor Cyan
    foreach ($s in (Get-AllSkills)) { Write-Host "  $s" -ForegroundColor Gray }

    Write-Host "`nAvailable targets:" -ForegroundColor Cyan
    'cursor', 'cursor-foundation', 'cursor-rules', 'agents', 'claude-code', 'codex', 'codex-agents-md', 'openclaw', 'raw' | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
}

function Copy-SkillToFile {
    param([string]$SrcPath, [string]$DestPath)

    if ($DryRun) {
        Write-Host "  [dry-run] would write $DestPath" -ForegroundColor DarkCyan
        return
    }

    $destDir = Split-Path $DestPath -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

    if (Test-Path $DestPath) {
        if (-not $Force) {
            $resp = Read-Host "  Overwrite $DestPath? [y/N]"
            if ($resp -notmatch '^[yY]') { Write-Host "  Skipped." -ForegroundColor Yellow; return }
        }
        else {
            $backup = Backup-File -FilePath $DestPath
            if ($backup) { Write-Host "  Backed up to $backup" -ForegroundColor DarkYellow }
        }
    }

    Copy-Item -Path $SrcPath -Destination $DestPath -Force
    Write-Host "  Wrote $DestPath" -ForegroundColor Green
}

function Backup-Directory {
    # Renames an existing directory to <name>.bak-<timestamp>. Returns the backup path,
    # or $null if the source did not exist.
    # When -NoBackup is set, the directory is removed instead and $null is returned
    # (caller will see no "Backed up to ..." line).
    param([string]$DirPath)

    if (-not (Test-Path $DirPath)) { return $null }

    if ($NoBackup) {
        Remove-Item -Path $DirPath -Recurse -Force
        return $null
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$DirPath.bak-$stamp"
    $i = 1
    while (Test-Path $backupPath) { $backupPath = "$DirPath.bak-$stamp-$i"; $i++ }

    Rename-Item -Path $DirPath -NewName (Split-Path $backupPath -Leaf)
    return $backupPath
}

function Backup-File {
    # Renames an existing file to <name>.bak-<timestamp>. Returns the backup path,
    # or $null if the source did not exist.
    # When -NoBackup is set, the file is removed instead and $null is returned.
    param([string]$FilePath)

    if (-not (Test-Path $FilePath -PathType Leaf)) { return $null }

    if ($NoBackup) {
        Remove-Item -Path $FilePath -Force
        return $null
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$FilePath.bak-$stamp"
    $i = 1
    while (Test-Path $backupPath) { $backupPath = "$FilePath.bak-$stamp-$i"; $i++ }

    Rename-Item -Path $FilePath -NewName (Split-Path $backupPath -Leaf)
    return $backupPath
}

function Test-AgentConfigCollision {
    param([string]$ProjectPath, [string]$Target)

    $hits = @()
    switch ($Target) {
        'cursor'          {
            if (Test-Path (Join-Path $ProjectPath '.cursor\skills')) { $hits += '.cursor/skills/' }
            if (Test-Path (Join-Path $ProjectPath '.cursor\rules'))  { $hits += '.cursor/rules/' }
        }
        'cursor-foundation' { if (Test-Path (Join-Path $ProjectPath '.cursor\rules'))  { $hits += '.cursor/rules/' } }
        'cursor-rules'    { if (Test-Path (Join-Path $ProjectPath '.cursor\rules'))  { $hits += '.cursor/rules/' } }
        'agents'          { if (Test-Path (Join-Path $ProjectPath '.agents\skills')) { $hits += '.agents/skills/' } }
        'claude-code'     { if (Test-Path (Join-Path $ProjectPath '.claude\agents')) { $hits += '.claude/agents/' } }
        'codex'           {
            if ($Scope -eq 'user') {
                $userSkills = Join-Path $env:USERPROFILE '.agents\skills'
                if (Test-Path $userSkills) { $hits += '~/.agents/skills/' }
            } else {
                if (Test-Path (Join-Path $ProjectPath '.agents\skills')) { $hits += '.agents/skills/' }
                if (Test-Path (Join-Path $ProjectPath 'AGENTS.md'))      { $hits += 'AGENTS.md' }
            }
        }
        'codex-agents-md' { if (Test-Path (Join-Path $ProjectPath 'AGENTS.md'))     { $hits += 'AGENTS.md' } }
        'openclaw'        { if (Test-Path (Join-Path $ProjectPath 'skills'))         { $hits += 'skills/' } }
        'raw'             { if (Test-Path (Join-Path $ProjectPath 'docs\ai-rules')) { $hits += 'docs/ai-rules/' } }
    }
    return $hits
}

function Test-GitWorkingTree {
    param([string]$ProjectPath)

    Push-Location $ProjectPath
    try {
        $null = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0) { return 'not-a-repo' }
        $status = git status --porcelain 2>$null
        if ([string]::IsNullOrWhiteSpace($status)) { return 'clean' }
        return 'dirty'
    }
    catch { return 'unknown' }
    finally { Pop-Location }
}

function Get-SkillBody {
    # Returns SKILL.md content with the YAML frontmatter stripped. The frontmatter
    # is metadata (used by Cursor / Claude Code to match rules); for Codex / raw
    # markdown ingestion, we want only the prompt body.
    param([string]$SrcPath)

    $content = Get-Content -Raw -Path $SrcPath
    if ($content -match "(?s)^---\r?\n.*?\r?\n---\r?\n(.+)$") {
        return $Matches[1].TrimStart()
    }
    return $content
}

# Foundation rules that ship as Cursor `alwaysApply: true` .mdc files even in
# the Skills-native `cursor` target. They need to be in scope on every turn,
# and Cursor Agent Skills are agent-requested by default — there is no
# alwaysApply equivalent inside `.cursor/skills/`. The legacy `cursor-rules`
# target also adds `meta/task-router` to this set (rules-only flow needs the
# router always on); the new `cursor` target lets task-router ship as a
# regular Skill alongside the others.
$Script:CursorAlwaysApplySkills = @(
    'meta/engineering-principles',
    'meta/reuse-before-create',
    'meta/token-discipline'
)

# Legacy cursor-rules target ALSO marks task-router as alwaysApply because in
# rules-only mode the router has to be the entry point (no Skills discovery).
$Script:CursorRulesAlwaysApplySkills = @(
    'meta/engineering-principles',
    'meta/reuse-before-create',
    'meta/token-discipline',
    'meta/task-router'
)

function Test-CursorAlwaysApply {
    param([string]$Skill)
    return $Script:CursorAlwaysApplySkills -contains $Skill
}

# Skills that should NOT be installed by the `cursor` or `agents` targets even
# if a profile (e.g. fullstack) includes them. `meta/task-router` is written
# for the OpenClaw / Claude Code subagent-orchestration model; under Cursor's
# and Codex's native Skills matchers it duplicates and fights the host's
# routing logic. The legacy `cursor-rules` and OpenClaw / Claude Code / Codex
# targets keep it because that's where it actually belongs.
$Script:CursorAgentsFilterSkills = @(
    'meta/task-router'
)

function Select-SkillsForCursorOrAgents {
    param([string[]]$SkillList)

    $filtered = @()
    $removed = @()
    foreach ($skill in $SkillList) {
        if ($Script:CursorAgentsFilterSkills -contains $skill) {
            $removed += $skill
        } else {
            $filtered += $skill
        }
    }
    if ($removed.Count -gt 0) {
        Write-Host "  Filtered out (incompatible with native Skills matcher): $($removed -join ', ')" -ForegroundColor DarkYellow
    }
    return ,$filtered
}

function Test-CursorRulesAlwaysApply {
    param([string]$Skill)
    return $Script:CursorRulesAlwaysApplySkills -contains $Skill
}

# Transform a generic SKILL.md into a Cursor-native .mdc rule.
#
# Cursor Project Rules require:
#   - .mdc extension (not .md, Cursor will not pick it up otherwise)
#   - Cursor-native frontmatter (description / globs / alwaysApply); our
#     generic `triggers:` and `applies_to:` are ignored by Cursor.
#   - description used by Cursor's Agent Requested mode to decide relevance.
#
# The body of the skill is preserved verbatim. Only the YAML frontmatter is
# rewritten.
function Write-CursorMdc {
    param(
        [string]$SrcPath,
        [string]$DestPath,
        [string]$Skill,
        [switch]$UseRulesAlwaysApply
    )

    $isAlways = if ($UseRulesAlwaysApply) {
        Test-CursorRulesAlwaysApply -Skill $Skill
    } else {
        Test-CursorAlwaysApply -Skill $Skill
    }
    $alwaysApply = if ($isAlways) { 'true' } else { 'false' }

    # PowerShell 5's `Get-Content -Raw` reads as ANSI/cp1252 by default, which
    # corrupts every non-ASCII character in the source SKILL.md (em-dashes,
    # Cyrillic, smart quotes). Read raw bytes and decode as UTF-8 explicitly.
    $raw = [System.IO.File]::ReadAllText($SrcPath, [System.Text.Encoding]::UTF8)

    # Extract original description and strip the frontmatter from the body.
    $description = ''
    if ($raw -match '^---\s*\r?\n([\s\S]*?)\r?\n---\s*\r?\n') {
        $fm = $Matches[1]
        if ($fm -match '(?m)^description:\s*(.+)$') {
            $description = $Matches[1].Trim()
        }
    }
    $body = $raw -replace '(?s)^---\s*\r?\n.*?\r?\n---\s*\r?\n', ''

    # Cursor-native frontmatter + original body.
    $newFrontmatter = @(
        '---',
        "description: $description",
        'globs:',
        "alwaysApply: $alwaysApply",
        '---',
        ''
    ) -join "`n"

    # PowerShell 5's `Set-Content -Encoding utf8` writes UTF-8 WITH BOM and silently
    # double-encodes non-ASCII strings via the ANSI pipeline (Cyrillic in our
    # multilingual bridge becomes mojibake: `п` -> bytes D0 BF -> reencoded as
    # C3 90 C2 BF). Bypass the pipeline entirely by writing raw bytes through
    # System.IO.File with an explicit UTF-8-without-BOM encoder. Cursor's YAML
    # frontmatter parser also dislikes a BOM before the opening `---`, so no BOM
    # is doubly correct here.
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($DestPath, ($newFrontmatter + $body), $utf8NoBom)
}

# Cursor 2.4+ Skills-native install.
#
# Cursor 2.4 ships native Agent Skills discovery at `.cursor/skills/<name>/SKILL.md`
# (and `.agents/skills/<name>/SKILL.md` as a fallback). Cursor reads only the
# `name` + `description` frontmatter to populate the skill list, then loads the
# body on demand — same progressive-disclosure model as Codex.
#
# We split the install:
#   - Three foundation rules (engineering-principles, reuse-before-create,
#     token-discipline) go to `.cursor/rules/*.mdc` with `alwaysApply: true`.
#     Skills are agent-requested by default and Cursor has no "alwaysApply"
#     for Skills, so we keep these as legacy rules.
#   - Every other skill (including `task-router`) goes to `.cursor/skills/<name>/SKILL.md`
#     as a Cursor Agent Skill folder. The frontmatter is rewritten to the
#     Agent Skills schema (just `name` + `description`).
#
# The legacy `prompt-pack-router.mdc` bridge is dropped: Skills discovery
# replaces it natively.
function Install-Cursor {
    param([string[]]$SkillList, [string]$ProjectPath)

    $skillsDir = Join-Path $ProjectPath '.cursor\skills'
    $rulesDir  = Join-Path $ProjectPath '.cursor\rules'

    Write-Host "`nInstalling to $ProjectPath\.cursor\" -ForegroundColor Cyan
    Write-Host "  Skills-native (Cursor 2.4+): foundation rules -> .cursor/rules/*.mdc, every other skill -> .cursor/skills/<name>/SKILL.md`n" -ForegroundColor DarkGray

    $SkillList = Select-SkillsForCursorOrAgents -SkillList $SkillList

    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
        New-Item -ItemType Directory -Force -Path $rulesDir  | Out-Null
    }

    foreach ($skill in $SkillList) {
        $name = ($skill -split '/')[-1]
        $srcDir = Join-Path $PromptsRoot ($skill -replace '/', '\')
        $src    = Join-Path $srcDir 'SKILL.md'
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        if (Test-CursorAlwaysApply -Skill $skill) {
            # Foundation rule — stays as legacy alwaysApply .mdc.
            $dest = Join-Path $rulesDir "$name.mdc"

            if ($DryRun) {
                Write-Host "  [dry-run] would write $dest  (alwaysApply: true)"
                continue
            }

            if (Test-Path $dest) {
                if (-not $Force) {
                    $resp = Read-Host "  Overwrite $dest? [y/N]"
                    if ($resp -notmatch '^[yY]') { Write-Host "  Skipped." -ForegroundColor Yellow; continue }
                }
                else {
                    $backup = Backup-File -FilePath $dest
                    if ($backup) { Write-Host "  Backed up to $backup" -ForegroundColor DarkYellow }
                }
            }

            Write-CursorMdc -SrcPath $src -DestPath $dest -Skill $skill
            Write-Host "  Wrote $dest  (alwaysApply: true)"
        }
        else {
            # Regular skill — ships as Cursor Agent Skill folder.
            $destDir = Join-Path $skillsDir $name

            if ($DryRun) {
                $action = if (Test-Path $destDir) { 'replace (existing renamed to .bak)' } else { 'create' }
                Write-Host "  [dry-run] would $action $destDir  (Cursor Agent Skill)" -ForegroundColor DarkCyan
                continue
            }

            if (Test-Path $destDir) {
                if (-not $Force -and -not $Script:ForceAll) {
                    $resp = Read-Host "  Replace $destDir? Existing will be renamed to <name>.bak-<timestamp>. [y/N/a]"
                    if ($resp -match '^[aA]$') {
                        $Script:ForceAll = $true
                        Write-Host "  Yes to all: subsequent skills will be replaced without prompting." -ForegroundColor DarkGray
                    } elseif ($resp -notmatch '^[yY]$') {
                        Write-Host "  Skipped." -ForegroundColor Yellow; continue
                    }
                }
                $backup = Backup-Directory -DirPath $destDir
                if ($backup) { Write-Host "  Backed up to $backup" -ForegroundColor DarkYellow }
            }

            Copy-Item -Path $srcDir -Destination $destDir -Recurse -Force

            # Rewrite SKILL.md frontmatter to Agent Skills schema (name + description only).
            $skillFile = Join-Path $destDir 'SKILL.md'
            if (Test-Path $skillFile) {
                Write-AgentSkillFrontmatter -SrcPath $src -DestPath $skillFile
            }

            Write-Host "  Wrote $destDir  (Cursor Agent Skill: $name)" -ForegroundColor Green
        }
    }

    Write-Host "`nDone. Reload your Cursor window to pick up the new skills." -ForegroundColor Cyan
    Write-Host "Foundation rules in .cursor/rules/ load on every turn; specialised skills in .cursor/skills/" -ForegroundColor DarkGray
    Write-Host "are picked up via Cursor's native skill discovery (name + description match)." -ForegroundColor DarkGray
}

# Normalize a raw YAML description value into a safely double-quoted string.
# Source SKILL.md files use a mix of plain scalars (most) and double-quoted
# scalars (e.g. when the description starts with a colon-bearing label).
# Writing the captured value verbatim breaks if the original was plain but
# contains characters that change meaning at the start of a YAML value once
# we re-emit it (`:`, `#`, leading quote). Always-quote with backslash-escaped
# inner quotes is the safe lowest-common-denominator form.
function Format-YamlDoubleQuoted {
    param([string]$RawValue)

    $value = $RawValue
    # Strip a single layer of YAML quoting if the captured raw value carries it
    # (the captured string includes surrounding quotes when the source frontmatter
    # used a quoted scalar).
    if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
        $value = $value.Substring(1, $value.Length - 2)
        # Reverse YAML's `\"` and `\\` escapes inside double-quoted strings.
        # In PowerShell `-replace`, the pattern is a regex (so `'\\"'` is regex
        # `\"`, matching one literal quote) and the replacement is a literal
        # string (`$` is the only special char). Order matters: undo `\"` first,
        # then `\\`, otherwise we'd convert an escaped backslash into a real
        # escape sequence on the next pass.
        $value = $value -replace '\\"', '"'
        $value = $value -replace '\\\\', '\\'
    } elseif ($value.Length -ge 2 -and $value.StartsWith("'") -and $value.EndsWith("'")) {
        $value = $value.Substring(1, $value.Length - 2)
        # Reverse YAML's `''` escape inside single-quoted strings.
        $value = $value -replace "''", "'"
    }

    # Escape backslash first, then double quote, for safe double-quoted YAML.
    # `-replace '\\', '\\'`  : regex `\\` matches one backslash; replacement string
    #                          `\\` is two literal backslashes.
    # `-replace '"', '\\"'`   : regex `"` matches a quote; replacement `\"` writes
    #                          backslash + quote.
    $escaped = $value -replace '\\', '\\' -replace '"', '\"'
    return '"' + $escaped + '"'
}

# Rewrite SKILL.md cross-skill links to a flat-install friendly form.
#
# In the source repo skills cross-reference each other with markdown links
# like `[``meta/engineering-principles``](../../meta/engineering-principles/SKILL.md)`.
# After install under a flat `.cursor/skills/<name>/` or `.agents/skills/<name>/`
# layout, those relative paths no longer resolve (the category directory is
# gone). Strip the link entirely and keep only the basename inside backticks,
# which is still recognisable as a skill reference.
#
# Examples:
#   [``meta/engineering-principles``](../../meta/engineering-principles/SKILL.md)
#       -> ``engineering-principles``
#   [``postgres-supabase``](../../architecture/postgres-supabase/SKILL.md)
#       -> ``postgres-supabase``
function Convert-CrossLinksForFlatInstall {
    param([string]$Body)

    return [regex]::Replace($Body, '\[`[^`]+`\]\([^)]*?/?([A-Za-z0-9._-]+)/SKILL\.md\)', {
        param($m)
        $basename = $m.Groups[1].Value
        return '`' + $basename + '`'
    })
}

# Rewrite a source SKILL.md frontmatter into the Agent Skills schema (name +
# description only). Body cross-skill links are also rewritten to text-only
# basenames so the flat `.cursor/skills/<name>/` / `.agents/skills/<name>/`
# layout doesn't leave broken `../../meta/foo/SKILL.md` paths behind.
function Write-AgentSkillFrontmatter {
    param([string]$SrcPath, [string]$DestPath)

    $raw = [System.IO.File]::ReadAllText($SrcPath, [System.Text.Encoding]::UTF8)

    $name = ''
    $description = ''
    if ($raw -match '^---\s*\r?\n([\s\S]*?)\r?\n---\s*\r?\n') {
        $fm = $Matches[1]
        if ($fm -match '(?m)^name:\s*(.+)$')        { $name = $Matches[1].Trim() }
        if ($fm -match '(?m)^description:\s*(.+)$') { $description = $Matches[1].Trim() }
    }
    $body = $raw -replace '(?s)^---\s*\r?\n.*?\r?\n---\s*\r?\n', ''
    $body = Convert-CrossLinksForFlatInstall -Body $body

    $quotedDescription = Format-YamlDoubleQuoted -RawValue $description

    $newFrontmatter = @(
        '---',
        "name: $name",
        "description: $quotedDescription",
        '---',
        ''
    ) -join "`n"

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($DestPath, ($newFrontmatter + $body), $utf8NoBom)
}

# Foundation-only Cursor install. Writes ONLY the three foundation rules
# (engineering-principles, reuse-before-create, token-discipline) to
# `.cursor/rules/*.mdc` with `alwaysApply: true`. No `.cursor/skills/`
# writes. The intent is to layer this on top of `-Target agents` (universal
# Skills install) so Cursor gets always-on foundation rules without
# producing a duplicate `.cursor/skills/` tree alongside `.agents/skills/`.
#
# Any non-foundation skills in $SkillList are silently dropped: this target
# is foundation-only by definition. The caller usually still passes a full
# profile because the same skill list is meant to feed `-Target agents` in
# the layered combo.
function Install-CursorFoundation {
    param([string[]]$SkillList, [string]$ProjectPath)

    $rulesDir = Join-Path $ProjectPath '.cursor\rules'

    Write-Host "`nInstalling foundation-only Cursor rules to $rulesDir" -ForegroundColor Cyan
    Write-Host "  (cursor-foundation: only the 3 alwaysApply rules; layer on top of -Target agents)`n" -ForegroundColor DarkGray

    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $rulesDir | Out-Null }

    # Restrict the input list to the foundation set, preserving order and
    # ignoring anything else the profile happened to include.
    $foundation = @($SkillList | Where-Object { Test-CursorAlwaysApply -Skill $_ })
    if ($foundation.Count -eq 0) {
        # Caller passed a profile that didn't include the foundation rules.
        # Fall back to the full canonical set so the target is still useful
        # in combo with `-Target agents`.
        $foundation = $Script:CursorAlwaysApplySkills
        Write-Host "  Profile didn't include foundation rules; installing the canonical set instead." -ForegroundColor DarkGray
    }

    $dropped = @($SkillList | Where-Object { -not (Test-CursorAlwaysApply -Skill $_) })
    if ($dropped.Count -gt 0) {
        Write-Host "  Skipping (not foundation rules): $($dropped -join ', ')" -ForegroundColor DarkYellow
    }

    foreach ($skill in $foundation) {
        $name = ($skill -split '/')[-1]
        $srcDir = Join-Path $PromptsRoot ($skill -replace '/', '\')
        $src    = Join-Path $srcDir 'SKILL.md'
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        $dest = Join-Path $rulesDir "$name.mdc"

        if ($DryRun) {
            Write-Host "  [dry-run] would write $dest  (alwaysApply: true)" -ForegroundColor DarkCyan
            continue
        }

        if (Test-Path $dest) {
            if (-not $Force) {
                $resp = Read-Host "  Overwrite $dest? [y/N]"
                if ($resp -notmatch '^[yY]') { Write-Host "  Skipped." -ForegroundColor Yellow; continue }
            }
            else {
                $backup = Backup-File -FilePath $dest
                if ($backup) { Write-Host "  Backed up to $backup" -ForegroundColor DarkYellow }
            }
        }

        Write-CursorMdc -SrcPath $src -DestPath $dest -Skill $skill
        Write-Host "  Wrote $dest  (alwaysApply: true)" -ForegroundColor Green
    }

    Write-Host "`nDone. Reload your Cursor window to pick up the new rules." -ForegroundColor Cyan
    Write-Host "This target writes ONLY foundation rules. For the specialised skills, run" -ForegroundColor DarkGray
    Write-Host "`-Target agents` against the same project (universal Skills layout that" -ForegroundColor DarkGray
    Write-Host "Cursor 2.4+, Codex CLI, and GitHub Copilot all read)." -ForegroundColor DarkGray
}

# Legacy Cursor target. Writes every skill to .cursor/rules/<name>.mdc plus a
# prompt-pack-router.mdc bridge. Kept for Cursor builds older than 2.4 or
# users who prefer the rules-only flow over Skills discovery.
function Install-CursorRules {
    param([string[]]$SkillList, [string]$ProjectPath)

    $rulesDir = Join-Path $ProjectPath '.cursor\rules'
    Write-Host "`nInstalling to $rulesDir" -ForegroundColor Cyan
    Write-Host "  (cursor-rules legacy target: writing .mdc Project Rules + bridge router)`n" -ForegroundColor DarkGray

    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $rulesDir | Out-Null }

    foreach ($skill in $SkillList) {
        $name = ($skill -split '/')[-1]
        $src = Join-Path $PromptsRoot ($skill -replace '/', '\') | Join-Path -ChildPath 'SKILL.md'
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        $dest = Join-Path $rulesDir "$name.mdc"
        $alwaysApply = Test-CursorRulesAlwaysApply -Skill $skill
        $mode = if ($alwaysApply) { 'always-apply' } else { 'agent-requested' }

        if ($DryRun) {
            Write-Host "  [dry-run] would write $dest  ($mode)"
            continue
        }

        if (Test-Path $dest) {
            if (-not $Force) {
                $resp = Read-Host "  Overwrite $dest? [y/N]"
                if ($resp -notmatch '^[yY]') { Write-Host "  Skipped." -ForegroundColor Yellow; continue }
            }
            else {
                $backup = Backup-File -FilePath $dest
                if ($backup) { Write-Host "  Backed up to $backup" -ForegroundColor DarkYellow }
            }
        }

        Write-CursorMdc -SrcPath $src -DestPath $dest -Skill $skill -UseRulesAlwaysApply
        if ($alwaysApply) {
            Write-Host "  Wrote $dest  (alwaysApply: true)"
        } else {
            Write-Host "  Wrote $dest  (agent-requested; invoke with @$name for explicit use)"
        }
    }

    # Bridge router: small always-apply rule that names the routing table so
    # specialised rules are discoverable on Cursor where our generic triggers
    # are invisible. Multilingual intent aliases live here.
    $bridgeDest = Join-Path $rulesDir 'prompt-pack-router.mdc'
    if ($DryRun) {
        Write-Host "  [dry-run] would write $bridgeDest  (always-apply bridge)"
    } else {
        if (Test-Path $bridgeDest) {
            if (-not $Force) {
                $resp = Read-Host "  Overwrite $bridgeDest? [y/N]"
                if ($resp -notmatch '^[yY]') {
                    Write-Host "  Skipped bridge router." -ForegroundColor Yellow
                } else {
                    Write-CursorBridgeRule -DestPath $bridgeDest
                    Write-Host "  Wrote $bridgeDest  (always-apply bridge)"
                }
            } else {
                $backup = Backup-File -FilePath $bridgeDest
                if ($backup) { Write-Host "  Backed up to $backup" -ForegroundColor DarkYellow }
                Write-CursorBridgeRule -DestPath $bridgeDest
                Write-Host "  Wrote $bridgeDest  (always-apply bridge)"
            }
        } else {
            Write-CursorBridgeRule -DestPath $bridgeDest
            Write-Host "  Wrote $bridgeDest  (always-apply bridge)"
        }
    }

    Write-Host "`nDone. Reload your Cursor window to pick up the new rules." -ForegroundColor Cyan
    Write-Host "Specialised rules are agent-requested; for critical workflows invoke them" -ForegroundColor DarkGray
    Write-Host "explicitly with @code-review, @security-review, @repo-audit, etc." -ForegroundColor DarkGray
}

# Universal Agent Skills target. Writes every skill to `.agents/skills/<name>/`
# without any AGENTS.md bridge. Compatible with Cursor 2.4+, Codex CLI, and
# GitHub Copilot from a single install.
#
# No always-apply rules: `.agents/skills/` is a skill-only layout, and adding
# a .cursor/rules/ side-channel would couple this target to Cursor. Users who
# need always-on foundation rules should layer the `cursor` target on top, or
# inline the engineering-principles content into their AGENTS.md manually.
function Install-Agents {
    param([string[]]$SkillList, [string]$ProjectPath)

    $skillsRoot = Join-Path $ProjectPath '.agents\skills'
    Write-Host "`nInstalling Agent Skills to $skillsRoot" -ForegroundColor Cyan
    Write-Host "  (universal target: works in Cursor 2.4+, Codex CLI, and GitHub Copilot)`n" -ForegroundColor DarkGray

    $SkillList = Select-SkillsForCursorOrAgents -SkillList $SkillList

    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null }

    foreach ($skill in $SkillList) {
        $name = ($skill -split '/')[-1]
        $srcDir = Join-Path $PromptsRoot ($skill -replace '/', '\')
        $src    = Join-Path $srcDir 'SKILL.md'
        if (-not (Test-Path $srcDir)) { Write-Host "  Missing: $srcDir" -ForegroundColor Red; continue }

        $destDir = Join-Path $skillsRoot $name

        if ($DryRun) {
            $action = if (Test-Path $destDir) { 'replace (existing renamed to .bak)' } else { 'create' }
            Write-Host "  [dry-run] would $action $destDir" -ForegroundColor DarkCyan
            continue
        }

        if (Test-Path $destDir) {
            if (-not $Force -and -not $Script:ForceAll) {
                $resp = Read-Host "  Replace $destDir? Existing will be renamed to <name>.bak-<timestamp>. [y/N/a]"
                if ($resp -match '^[aA]$') {
                    $Script:ForceAll = $true
                    Write-Host "  Yes to all: subsequent skills will be replaced without prompting." -ForegroundColor DarkGray
                } elseif ($resp -notmatch '^[yY]$') {
                    Write-Host "  Skipped." -ForegroundColor Yellow; continue
                }
            }
            $backup = Backup-Directory -DirPath $destDir
            if ($backup) { Write-Host "  Backed up to $backup" -ForegroundColor DarkYellow }
        }

        Copy-Item -Path $srcDir -Destination $destDir -Recurse -Force

        # Rewrite frontmatter to Agent Skills schema (name + description only).
        $skillFile = Join-Path $destDir 'SKILL.md'
        if (Test-Path $skillFile) {
            Write-AgentSkillFrontmatter -SrcPath $src -DestPath $skillFile
        }

        Write-Host "  Wrote $destDir  (Agent Skill: $name)" -ForegroundColor Green
    }

    Write-Host "`nDone. Restart your AI tool to pick up the new skills." -ForegroundColor Cyan
    Write-Host "Skills are discovered by name + description (Cursor 2.4+, Codex, GitHub Copilot)." -ForegroundColor DarkGray
    Write-Host "Need always-on foundation rules? Layer `-Target cursor-foundation` on top of this install." -ForegroundColor DarkGray
}

function Write-CursorBridgeRule {
    param([string]$DestPath)

    # Bridge content is stored as a separate file (templates/cursor-bridge.mdc)
    # rather than embedded in this script. PowerShell 5 reads source files as
    # ANSI/cp1252 unless they have a UTF-8 BOM, which silently double-encodes
    # any Cyrillic literal in the script (п -> bytes D0 BF -> reencoded as
    # mojibake C3 90 C2 BF). Copying the template's bytes verbatim with
    # Copy-Item bypasses the entire encoding pipeline. The template is locked
    # to UTF-8 LF in .gitattributes.
    $templatePath = Join-Path $PSScriptRoot 'templates\cursor-bridge.mdc'
    if (-not (Test-Path $templatePath)) {
        Write-Host "  Warning: bridge template not found at $templatePath; skipping bridge rule." -ForegroundColor Yellow
        return
    }
    Copy-Item -Path $templatePath -Destination $DestPath -Force
}

function Install-ClaudeCode {
    param([string[]]$SkillList, [string]$ProjectPath)

    $agentsDir = Join-Path $ProjectPath '.claude\agents'
    Write-Host "`nInstalling to $agentsDir`n" -ForegroundColor Cyan

    foreach ($skill in $SkillList) {
        $name = ($skill -split '/')[-1]
        $src = Join-Path $PromptsRoot ($skill -replace '/', '\') | Join-Path -ChildPath 'SKILL.md'
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        $dest = Join-Path $agentsDir "$name.md"
        Copy-SkillToFile -SrcPath $src -DestPath $dest
    }

    Write-Host "`nDone. Claude Code will pick up the agents on next start." -ForegroundColor Cyan
}

# Codex-native install.
#
# Per the official Codex skills documentation
# (https://developers.openai.com/codex/skills), each skill is a directory
# with a SKILL.md file under one of the discovery roots:
#
#   - REPO: <project>/.agents/skills/<name>/SKILL.md
#   - USER: $HOME/.agents/skills/<name>/SKILL.md
#   - ADMIN: /etc/codex/skills/<name>/SKILL.md (we don't write here)
#
# Codex uses progressive disclosure: it reads only `name` and `description`
# from the frontmatter for the initial skill list (capped at ~2% of context
# or 8000 chars), and loads the full SKILL.md when the skill is selected.
#
# Our SKILL.md frontmatter already carries `name` + `description`, so we can
# copy each skill folder verbatim. Extra fields (`category`, `version`,
# `triggers`, `applies_to`) are ignored by Codex but useful as metadata, so
# we leave them in place.
#
# We also write a compact AGENTS.md (~3 KB) at the repo root with the
# multilingual routing bridge so Codex picks the right skill when the user
# writes in Russian/Ukrainian. The full skill bodies stay in the skill
# folders; AGENTS.md only mentions skill names + intent aliases.
# Skills that exist as foundation rules: Cursor marks them alwaysApply, Codex
# has no inheritance model so we instead opt them out of implicit invocation.
# Codex will still surface them in the skill list (so the user can explicitly
# call `$engineering-principles` to remind themselves of the rules) but will
# not auto-select them when matching a task description against installed
# skill descriptions.
#
# This matches `triggers: [inherit-only]` in the source SKILL.md frontmatter.
$Script:CodexInheritOnlySkills = @(
    'meta/engineering-principles',
    'meta/reuse-before-create',
    'meta/token-discipline',
    'meta/task-router'
)

function Test-CodexInheritOnly {
    param([string]$Skill)
    return $Script:CodexInheritOnlySkills -contains $Skill
}

# Write a minimal agents/openai.yaml that disables implicit invocation for
# foundation skills. Schema: developers.openai.com/codex/skills.
function Write-CodexOpenaiYaml {
    param([string]$DestDir)

    $agentsDir = Join-Path $DestDir 'agents'
    if (-not (Test-Path $agentsDir)) { New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null }

    $yaml = @(
        '# Disable implicit invocation: this skill is foundation/inherit-only.',
        '# Codex will still list it; the user can call $<name> explicitly.',
        'policy:',
        '  allow_implicit_invocation: false',
        ''
    ) -join "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $agentsDir 'openai.yaml'), $yaml, $utf8NoBom)
}

# Rewrite the source SKILL.md cross-skill links into a Codex-friendly form.
# In the repo, skills cross-reference each other with markdown links like
# `[`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md)`.
# Under the flat .agents/skills/ layout those relative paths don't resolve
# and the `meta/` category prefix in the label is misleading.
#
# We rewrite to a hybrid form that is both a valid Codex skill reference
# (the inline-code label `$<name>` is what Codex matches) and a working
# relative markdown link in the new layout (so a reader in their editor
# can still ctrl/cmd-click through to the referenced SKILL.md).
#
# Examples:
#   [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md)
#       -> [`$engineering-principles`](../engineering-principles/SKILL.md)
#   [`postgres-supabase`](../postgres-supabase/SKILL.md)
#       -> [`$postgres-supabase`](../postgres-supabase/SKILL.md)
function Convert-CrossLinksForCodex {
    param([string]$Body, [hashtable]$InstalledNames = $null)

    return [regex]::Replace($Body, '\[`([^`]+)`\]\([^)]*?/?([A-Za-z0-9._-]+)/SKILL\.md\)', {
        param($m)
        # Prefer the basename from the URL (last segment before /SKILL.md)
        # over the bracketed label, because the label sometimes carries the
        # legacy `category/name` form.
        $basename = $m.Groups[2].Value
        if ($InstalledNames -and -not $InstalledNames.ContainsKey($basename)) {
            return '`$' + $basename + '`'
        }
        return '[`$' + $basename + '`](../' + $basename + '/SKILL.md)'
    })
}

function Install-Codex {
    param([string[]]$SkillList, [string]$ProjectPath, [string]$Scope)

    if ($Scope -eq 'user') {
        $skillsRoot = Join-Path $env:USERPROFILE '.agents\skills'
        $scopeLabel = 'user (~/.agents/skills/)'
        $writeAgentsMd = $false
    } else {
        $skillsRoot = Join-Path $ProjectPath '.agents\skills'
        $scopeLabel = 'repo (.agents/skills/)'
        $writeAgentsMd = $true
    }

    Write-Host "`nInstalling Codex skills to $skillsRoot" -ForegroundColor Cyan
    Write-Host "  (scope: $scopeLabel; format: Codex-native skill folders with progressive disclosure)`n" -ForegroundColor DarkGray

    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null }

    $installedNames = @{}
    foreach ($s in $SkillList) {
        $installedNames[($s -split '/')[-1]] = $true
    }

    foreach ($skill in $SkillList) {
        $name = ($skill -split '/')[-1]
        $src = Join-Path $PromptsRoot ($skill -replace '/', '\')
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        $dest = Join-Path $skillsRoot $name

        if ($DryRun) {
            $action = if (Test-Path $dest) { 'replace (existing renamed to .bak)' } else { 'create' }
            Write-Host "  [dry-run] would $action $dest" -ForegroundColor DarkCyan
            continue
        }

        if (Test-Path $dest) {
            if (-not $Force -and -not $Script:ForceAll) {
                $resp = Read-Host "  Replace $dest? Existing will be renamed to <name>.bak-<timestamp>. [y/N/a]"
                if ($resp -match '^[aA]$') {
                    $Script:ForceAll = $true
                    Write-Host "  Yes to all: subsequent skills will be replaced without prompting." -ForegroundColor DarkGray
                } elseif ($resp -notmatch '^[yY]$') {
                    Write-Host "  Skipped." -ForegroundColor Yellow; continue
                }
            }
            $backup = Backup-Directory -DirPath $dest
            if ($backup) { Write-Host "  Backed up to $backup" -ForegroundColor DarkYellow }
        }

        Copy-Item -Path $src -Destination $dest -Recurse -Force

        # Rewrite cross-skill links inside the copied SKILL.md so they refer
        # to Codex skill names ($foo) instead of relative ../meta/foo/SKILL.md
        # paths that don't exist under the flat .agents/skills/ layout.
        $skillFile = Join-Path $dest 'SKILL.md'
        if (Test-Path $skillFile) {
            $body = [System.IO.File]::ReadAllText($skillFile, [System.Text.Encoding]::UTF8)
            $body = Convert-CrossLinksForCodex -Body $body -InstalledNames $installedNames
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($skillFile, $body, $utf8NoBom)
        }

        # Mark foundation skills as explicit-only so Codex doesn't auto-select
        # them based on description match.
        $isInheritOnly = Test-CodexInheritOnly -Skill $skill
        if ($isInheritOnly) {
            Write-CodexOpenaiYaml -DestDir $dest
            Write-Host "  Wrote $dest  (skill: $name, explicit-only)" -ForegroundColor Green
        } else {
            Write-Host "  Wrote $dest  (skill: $name)" -ForegroundColor Green
        }
    }

    if ($writeAgentsMd) {
        $agentsFile = Join-Path $ProjectPath 'AGENTS.md'
        if ($DryRun) {
            $verb = if (Test-Path $agentsFile) { 'replace' } else { 'create' }
            Write-Host "`n  [dry-run] would $verb $agentsFile (compact router bridge)" -ForegroundColor DarkCyan
        } else {
            $writeBridge = $true
            if (Test-Path $agentsFile) {
                if (-not $Force) {
                    $resp = Read-Host "`n$agentsFile exists. Overwrite with prompt-pack router bridge? [y/N]"
                    if ($resp -notmatch '^[yY]') {
                        Write-Host "  Skipped AGENTS.md." -ForegroundColor Yellow
                        $writeBridge = $false
                    }
                } else {
                    $backup = Backup-File -FilePath $agentsFile
                    if ($backup) { Write-Host "  Backed up existing AGENTS.md to $backup" -ForegroundColor DarkYellow }
                }
            }
            if ($writeBridge) {
                Write-CodexAgentsMd -DestPath $agentsFile -SkillList $SkillList
                Write-Host "  Wrote $agentsFile  (compact router bridge)" -ForegroundColor Green
            }
        }
    }

    Write-Host "`nDone. Restart Codex to pick up the new skills." -ForegroundColor Cyan
    Write-Host "Skills are activated via `$<skill-name>` (explicit) or by Codex matching the description (implicit)." -ForegroundColor DarkGray
    if ($Scope -eq 'user') {
        Write-Host "User-scoped skills apply to every Codex session, regardless of working directory." -ForegroundColor DarkGray
    } else {
        Write-Host "Repo-scoped skills apply when Codex is launched inside this project." -ForegroundColor DarkGray
    }
}

# Emit a compact AGENTS.md (~2 KB) that names the installed skills and the
# multilingual intent aliases. The full skill bodies live in
# .agents/skills/<name>/SKILL.md and are loaded by Codex on demand, so this
# file deliberately stays small to avoid eating into Codex's 32 KiB
# project_doc_max_bytes budget.
#
# The template lives in `templates/codex-agents-md.md` and contains a
# `<!-- PROMPT_PACK_SKILL_LIST -->` placeholder. We read the template as raw
# UTF-8 bytes (PowerShell 5 mangles non-ASCII string literals embedded in
# .ps1 sources, so the multilingual aliases must come from a separate file)
# and substitute the skill list before writing.
# Routing rules: list of (intent label, [target skill names]) tuples. We emit
# the rule only if at least one target skill is in the installed set, and we
# keep only the installed targets in the rendered line. This keeps the
# AGENTS.md honest for any profile (minimal -> no `$code-review` rule, etc.)
# instead of pointing Codex at skills that aren't there.
$Script:CodexRoutingRules = @(
    @{ Label = 'PR / diff review';         Targets = @('code-review') },
    @{ Label = 'Repo-wide audit / no diff'; Targets = @('repo-audit') },
    @{ Label = 'Security review';          Targets = @('security-review') },
    @{ Label = 'Frontend feature or page'; Targets = @('frontend-feature') },
    @{ Label = 'Frontend audit';           Targets = @('frontend-audit') },
    @{ Label = 'Backend endpoint / API';   Targets = @('backend-api') },
    @{ Label = 'DB schema / migrations';   Targets = @('database-schema', 'database-migrations') },
    @{ Label = 'DB review';                Targets = @('database-review') },
    @{ Label = 'Refactor request';         Targets = @('refactor-planner') },
    @{ Label = 'Duplication audit';        Targets = @('duplication-audit') },
    @{ Label = 'Bug investigation';        Targets = @('debugger') },
    @{ Label = 'Test writing';             Targets = @('test-writer') },
    @{ Label = 'Documentation';            Targets = @('doc-writer') },
    @{ Label = 'UI design';                Targets = @('ui-designer') },
    @{ Label = 'Dockerfile / compose / containerize'; Targets = @('docker') },
    @{ Label = 'Handoff / wrap-up';        Targets = @('handoff') }
)

function Write-CodexAgentsMd {
    param([string]$DestPath, [string[]]$SkillList)

    $templatePath = Join-Path $PSScriptRoot 'templates\codex-agents-md.md'
    if (-not (Test-Path $templatePath)) {
        Write-Host "  Warning: AGENTS.md template not found at $templatePath; skipping AGENTS.md generation." -ForegroundColor Yellow
        return
    }

    $template = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)

    # Build the set of installed skill names (basename, after the last `/`).
    $installedSet = @{}
    foreach ($s in $SkillList) {
        $name = ($s -split '/')[-1]
        $installedSet[$name] = $true
    }

    # Rendered "### Installed skills" list.
    $skillLines = ($SkillList | ForEach-Object {
        $name = ($_ -split '/')[-1]
        "- ``$" + $name + "``"
    }) -join "`n"

    # Rendered "### Routing rules" list, filtered to installed skills only.
    # Format the label with a fixed-width pad so the arrows align in markdown.
    $maxLabel = 0
    $emittedRules = @()
    foreach ($rule in $Script:CodexRoutingRules) {
        $availableTargets = @($rule.Targets | Where-Object { $installedSet.ContainsKey($_) })
        if ($availableTargets.Count -eq 0) { continue }
        $emittedRules += [pscustomobject]@{ Label = $rule.Label; Targets = $availableTargets }
        if ($rule.Label.Length -gt $maxLabel) { $maxLabel = $rule.Label.Length }
    }
    $routingLines = if ($emittedRules.Count -eq 0) {
        '_(No specialised skills installed; the agent will answer ad-hoc.)_'
    } else {
        ($emittedRules | ForEach-Object {
            $labelPadded = $_.Label.PadRight($maxLabel)
            $targetStr = ($_.Targets | ForEach-Object { "``" + '$' + $_ + "``" }) -join ' / '
            "- $labelPadded -> $targetStr"
        }) -join "`n"
    }

    $rendered = $template.Replace('<!-- PROMPT_PACK_SKILL_LIST -->', $skillLines)
    $rendered = $rendered.Replace('<!-- PROMPT_PACK_ROUTING_RULES -->', $routingLines)

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($DestPath, $rendered, $utf8NoBom)
}

# Legacy single-file Codex install. Concatenates all skills into one
# AGENTS.md, capped at 32 KiB. Kept for hosts that do not yet support
# `.agents/skills/` (or for users who explicitly want one big project doc).
# Prefer `-Target codex` for everything else.
function Install-CodexAgentsMd {
    param([string[]]$SkillList, [string]$ProjectPath)

    $agentsFile = Join-Path $ProjectPath 'AGENTS.md'
    Write-Host "`nBuilding $agentsFile from $($SkillList.Count) skills (legacy single-file mode)`n" -ForegroundColor Cyan

    if ($DryRun) {
        $verb = if (Test-Path $agentsFile) { 'replace' } else { 'create' }
        Write-Host "  [dry-run] would $verb $agentsFile from $($SkillList.Count) skills" -ForegroundColor DarkCyan
        return
    }

    if (Test-Path $agentsFile) {
        if (-not $Force) {
            $resp = Read-Host "$agentsFile exists. Overwrite? [y/N]"
            if ($resp -notmatch '^[yY]') { Write-Host "Aborted." -ForegroundColor Yellow; return }
        }
        else {
            $backup = Backup-File -FilePath $agentsFile
            if ($backup) { Write-Host "Backed up existing AGENTS.md to $backup" -ForegroundColor DarkYellow }
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Agent Instructions')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Generated by prompt-pack install.ps1. Do not edit by hand; re-run the')
    [void]$sb.AppendLine('installer to update. Source: https://github.com/Ozzeron/prompt-pack')
    [void]$sb.AppendLine()

    $totalBytes = $sb.Length
    $sizeLimit = 32 * 1024  # Codex project_doc_max_bytes default
    $included = @()
    $skipped = @()

    foreach ($skill in $SkillList) {
        $src = Join-Path $PromptsRoot ($skill -replace '/', '\') | Join-Path -ChildPath 'SKILL.md'
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        $body = Get-SkillBody -SrcPath $src
        # Strip relative cross-skill links (e.g. [meta/foo](../foo/SKILL.md)) that are
        # valid source cross-references but become broken paths once all skills are
        # inlined into a single AGENTS.md. The referenced skill is already present as
        # a separate section in the same file.
        $body = $body -replace '\[([^\]]+)\]\(\.\./[^)]+/SKILL\.md\)', '$1'
        $section = "`n---`n`n<!-- skill: $skill -->`n$body`n"

        $candidateSize = $totalBytes + $section.Length
        if ($candidateSize -gt $sizeLimit) {
            $skipped += $skill
            continue
        }

        [void]$sb.Append($section)
        $totalBytes = $candidateSize
        $included += $skill
        Write-Host "  Included $skill" -ForegroundColor Green
    }

    Set-Content -Path $agentsFile -Value $sb.ToString() -Encoding UTF8
    Write-Host "`nWrote $agentsFile ($([math]::Round($totalBytes / 1024, 1)) KB / 32 KB limit)" -ForegroundColor Cyan

    if ($skipped.Count -gt 0) {
        Write-Host "`nSkipped (would exceed Codex 32 KB limit):" -ForegroundColor Yellow
        foreach ($s in $skipped) { Write-Host "  $s" -ForegroundColor Yellow }
        Write-Host "`nTip: switch to '-Target codex' (Codex-native, progressive disclosure) instead of dumping everything into one AGENTS.md." -ForegroundColor DarkGray
    }
}

function Install-OpenClaw {
    param([string[]]$SkillList, [string]$ProjectPath)

    $skillsDir = Join-Path $ProjectPath 'skills'
    Write-Host "`nInstalling skill directories to $skillsDir`n" -ForegroundColor Cyan

    foreach ($skill in $SkillList) {
        $name = ($skill -split '/')[-1]
        $src = Join-Path $PromptsRoot ($skill -replace '/', '\')
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        $dest = Join-Path $skillsDir $name

        if ($DryRun) {
            $action = if (Test-Path $dest) { 'replace (existing renamed to .bak)' } else { 'create' }
            Write-Host "  [dry-run] would $action $dest" -ForegroundColor DarkCyan
            continue
        }

        if (Test-Path $dest) {
            if (-not $Force -and -not $Script:ForceAll) {
                $resp = Read-Host "  Replace $dest? Existing will be renamed to <name>.bak-<timestamp>. [y/N/a]"
                if ($resp -match '^[aA]$') {
                    $Script:ForceAll = $true
                    Write-Host "  Yes to all: subsequent skills will be replaced without prompting." -ForegroundColor DarkGray
                } elseif ($resp -notmatch '^[yY]$') {
                    Write-Host "  Skipped." -ForegroundColor Yellow; continue
                }
            }
            $backup = Backup-Directory -DirPath $dest
            if ($backup) { Write-Host "  Backed up to $backup" -ForegroundColor DarkYellow }
        }

        if (-not (Test-Path $skillsDir)) { New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null }
        Copy-Item -Path $src -Destination $dest -Recurse -Force
        Write-Host "  Wrote $dest" -ForegroundColor Green
    }

    Write-Host "`nDone." -ForegroundColor Cyan
    Write-Host "Backups (if any) are in $skillsDir as <name>.bak-<timestamp> directories." -ForegroundColor DarkGray
    Write-Host "Delete them when you're confident the new version works." -ForegroundColor DarkGray
}

function Install-Raw {
    param([string[]]$SkillList, [string]$ProjectPath)

    $rawDir = Join-Path $ProjectPath 'docs\ai-rules'
    Write-Host "`nInstalling raw markdown bodies to $rawDir`n" -ForegroundColor Cyan

    foreach ($skill in $SkillList) {
        $name = ($skill -split '/')[-1]
        $src = Join-Path $PromptsRoot ($skill -replace '/', '\') | Join-Path -ChildPath 'SKILL.md'
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        $body = Get-SkillBody -SrcPath $src
        $dest = Join-Path $rawDir "$name.md"

        if ($DryRun) {
            $action = if (Test-Path $dest) { 'overwrite' } else { 'create' }
            Write-Host "  [dry-run] would $action $dest" -ForegroundColor DarkCyan
            continue
        }

        $destDirectory = Split-Path $dest -Parent
        if (-not (Test-Path $destDirectory)) { New-Item -ItemType Directory -Path $destDirectory -Force | Out-Null }

        if ((Test-Path $dest) -and -not $Force) {
            $resp = Read-Host "  Overwrite $dest? [y/N]"
            if ($resp -notmatch '^[yY]') { Write-Host "  Skipped." -ForegroundColor Yellow; continue }
        }

        Set-Content -Path $dest -Value $body -Encoding UTF8
        Write-Host "  Wrote $dest" -ForegroundColor Green
    }

    Write-Host "`nDone. Paste any of these into your AI tool's system-prompt / custom-instructions field." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if ($List) { Show-List; exit 0 }

if (-not $Target) {
    Write-Host "Error: -Target is required (cursor / cursor-foundation / cursor-rules / agents / claude-code / codex / codex-agents-md / openclaw / raw)." -ForegroundColor Red
    Write-Host "Run with -List to see available profiles and skills."
    exit 1
}

$projectPath = (Resolve-Path $Path -ErrorAction Stop).Path
if (-not (Test-Path $projectPath)) {
    Write-Host "Error: project path does not exist: $projectPath" -ForegroundColor Red
    exit 1
}

$skillList = Resolve-SkillList -ProfileName $Profile -ExplicitSkills $Skills
if (-not $skillList -or $skillList.Count -eq 0) {
    Write-Host "Error: no skills resolved (profile=$Profile)." -ForegroundColor Red
    exit 1
}

Write-Host "Target:  $Target" -ForegroundColor Cyan
Write-Host "Profile: $(if ($Skills) { 'custom (' + $Skills.Count + ' skills)' } else { $Profile })" -ForegroundColor Cyan
Write-Host "Path:    $projectPath" -ForegroundColor Cyan
Write-Host "Skills:  $($skillList.Count)" -ForegroundColor Cyan
if ($DryRun) { Write-Host "Mode:    dry-run (no changes will be made)" -ForegroundColor Yellow }
if ($Force)  { Write-Host "Mode:    force (existing files replaced; directories backed up to .bak-<timestamp>)" -ForegroundColor Yellow }

# Pre-flight warnings
$existing = Test-AgentConfigCollision -ProjectPath $projectPath -Target $Target
if ($existing.Count -gt 0) {
    Write-Host ""
    Write-Host "Notice: agent-config already present at:" -ForegroundColor Yellow
    foreach ($p in $existing) { Write-Host "  $p" -ForegroundColor Yellow }
    Write-Host "This run will modify or replace it. Use -DryRun first if unsure." -ForegroundColor Yellow
    Write-Host "Tip: rerun with -Force to replace silently (existing files are still backed up to .bak-<timestamp>)," -ForegroundColor DarkGray
    Write-Host "     or answer 'a' (yes-to-all) at the first prompt to skip the rest." -ForegroundColor DarkGray
}

$gitState = Test-GitWorkingTree -ProjectPath $projectPath
if ($gitState -eq 'dirty') {
    Write-Host ""
    Write-Host "Notice: git working tree is dirty. Consider committing or stashing before installing" -ForegroundColor Yellow
    Write-Host "so you can review changes via 'git diff' afterwards." -ForegroundColor Yellow
}
elseif ($gitState -eq 'not-a-repo') {
    Write-Host ""
    Write-Host "Notice: this directory isn't a git repository. Without git, undoing a bad install" -ForegroundColor Yellow
    Write-Host "requires manual deletion of the files this script writes." -ForegroundColor Yellow
}

switch ($Target) {
    'cursor'            { Install-Cursor           -SkillList $skillList -ProjectPath $projectPath }
    'cursor-foundation' { Install-CursorFoundation -SkillList $skillList -ProjectPath $projectPath }
    'cursor-rules'      { Install-CursorRules      -SkillList $skillList -ProjectPath $projectPath }
    'agents'            { Install-Agents           -SkillList $skillList -ProjectPath $projectPath }
    'claude-code'       { Install-ClaudeCode       -SkillList $skillList -ProjectPath $projectPath }
    'codex'             { Install-Codex            -SkillList $skillList -ProjectPath $projectPath -Scope $Scope }
    'codex-agents-md'   { Install-CodexAgentsMd    -SkillList $skillList -ProjectPath $projectPath }
    'openclaw'          { Install-OpenClaw         -SkillList $skillList -ProjectPath $projectPath }
    'raw'               { Install-Raw              -SkillList $skillList -ProjectPath $projectPath }
}

