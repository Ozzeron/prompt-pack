<#
.SYNOPSIS
  Install prompt-pack skills into a project directory.

.DESCRIPTION
  Copies a curated set of skills from this prompt-pack into the right location
  for your AI tool of choice (Cursor, Claude Code, Codex CLI, OpenClaw, or as
  loose markdown for any other tool).

.PARAMETER Target
  Where to install. One of: cursor, claude-code, codex, codex-agents-md, openclaw, raw

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
    [ValidateSet('cursor', 'claude-code', 'codex', 'codex-agents-md', 'openclaw', 'raw')]
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
    'cursor', 'claude-code', 'codex', 'codex-agents-md', 'openclaw', 'raw' | ForEach-Object {
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
    param([string]$DirPath)

    if (-not (Test-Path $DirPath)) { return $null }

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
    param([string]$FilePath)

    if (-not (Test-Path $FilePath -PathType Leaf)) { return $null }

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
        'cursor'          { if (Test-Path (Join-Path $ProjectPath '.cursor\rules'))  { $hits += '.cursor/rules/' } }
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

# Skills that should ship as Cursor `alwaysApply: true` rules: the meta layer
# (foundation rules the pack inherits) plus the orchestrator router. Every
# other skill ships as `alwaysApply: false` and is reachable via `@<name>`
# (Manual mode) or Cursor's Agent Requested mode using the rule's description.
# Cursor does not read our generic `triggers:` field, so these three Cursor-
# native frontmatter fields are the only way the rules surface automatically.
$Script:CursorAlwaysApplySkills = @(
    'meta/engineering-principles',
    'meta/reuse-before-create',
    'meta/token-discipline',
    'meta/task-router'
)

function Test-CursorAlwaysApply {
    param([string]$Skill)
    return $Script:CursorAlwaysApplySkills -contains $Skill
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
        [string]$Skill
    )

    $alwaysApply = if (Test-CursorAlwaysApply -Skill $Skill) { 'true' } else { 'false' }

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

function Install-Cursor {
    param([string[]]$SkillList, [string]$ProjectPath)

    $rulesDir = Join-Path $ProjectPath '.cursor\rules'
    Write-Host "`nInstalling to $rulesDir" -ForegroundColor Cyan
    Write-Host "  (Cursor target: writing .mdc Project Rules with Cursor-native frontmatter)`n" -ForegroundColor DarkGray

    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $rulesDir | Out-Null }

    foreach ($skill in $SkillList) {
        $name = ($skill -split '/')[-1]
        $src = Join-Path $PromptsRoot ($skill -replace '/', '\') | Join-Path -ChildPath 'SKILL.md'
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        $dest = Join-Path $rulesDir "$name.mdc"
        $alwaysApply = Test-CursorAlwaysApply -Skill $skill
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

        Write-CursorMdc -SrcPath $src -DestPath $dest -Skill $skill
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
            if (-not $Force) {
                $resp = Read-Host "  Replace $dest? Existing will be renamed to <name>.bak-<timestamp>. [y/N]"
                if ($resp -notmatch '^[yY]') { Write-Host "  Skipped." -ForegroundColor Yellow; continue }
            }
            $backup = Backup-Directory -DirPath $dest
            if ($backup) { Write-Host "  Backed up to $backup" -ForegroundColor DarkYellow }
        }

        Copy-Item -Path $src -Destination $dest -Recurse -Force
        Write-Host "  Wrote $dest  (skill: $name)" -ForegroundColor Green
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
function Write-CodexAgentsMd {
    param([string]$DestPath, [string[]]$SkillList)

    $templatePath = Join-Path $PSScriptRoot 'templates\codex-agents-md.md'
    if (-not (Test-Path $templatePath)) {
        Write-Host "  Warning: AGENTS.md template not found at $templatePath; skipping AGENTS.md generation." -ForegroundColor Yellow
        return
    }

    $template = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)
    $skillLines = ($SkillList | ForEach-Object {
        $name = ($_ -split '/')[-1]
        "- ``$" + $name + "``"
    }) -join "`n"

    $rendered = $template.Replace('<!-- PROMPT_PACK_SKILL_LIST -->', $skillLines)

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
            if (-not $Force) {
                $resp = Read-Host "  Replace $dest? Existing will be renamed to <name>.bak-<timestamp>. [y/N]"
                if ($resp -notmatch '^[yY]') { Write-Host "  Skipped." -ForegroundColor Yellow; continue }
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
    Write-Host "Error: -Target is required (cursor / claude-code / codex / openclaw / raw)." -ForegroundColor Red
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
    'cursor'          { Install-Cursor         -SkillList $skillList -ProjectPath $projectPath }
    'claude-code'     { Install-ClaudeCode     -SkillList $skillList -ProjectPath $projectPath }
    'codex'           { Install-Codex          -SkillList $skillList -ProjectPath $projectPath -Scope $Scope }
    'codex-agents-md' { Install-CodexAgentsMd  -SkillList $skillList -ProjectPath $projectPath }
    'openclaw'        { Install-OpenClaw       -SkillList $skillList -ProjectPath $projectPath }
    'raw'             { Install-Raw            -SkillList $skillList -ProjectPath $projectPath }
}
