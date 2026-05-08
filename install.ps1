<#
.SYNOPSIS
  Install prompt-pack skills into a project directory.

.DESCRIPTION
  Copies a curated set of skills from this prompt-pack into the right location
  for your AI tool of choice (Cursor, Claude Code, Codex CLI, OpenClaw, or as
  loose markdown for any other tool).

.PARAMETER Target
  Where to install. One of: cursor, claude-code, codex, openclaw, raw

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
    [ValidateSet('cursor', 'claude-code', 'codex', 'openclaw', 'raw')]
    [string]$Target,

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
        'review/database-review',
        'review/security-review',
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
    'cursor', 'claude-code', 'codex', 'openclaw', 'raw' | ForEach-Object {
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

    if ((Test-Path $DestPath) -and -not $Force) {
        $resp = Read-Host "  Overwrite $DestPath? [y/N]"
        if ($resp -notmatch '^[yY]') { Write-Host "  Skipped." -ForegroundColor Yellow; return }
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

function Test-AgentConfigCollision {
    param([string]$ProjectPath, [string]$Target)

    $hits = @()
    switch ($Target) {
        'cursor'      { if (Test-Path (Join-Path $ProjectPath '.cursor\rules'))  { $hits += '.cursor/rules/' } }
        'claude-code' { if (Test-Path (Join-Path $ProjectPath '.claude\agents')) { $hits += '.claude/agents/' } }
        'codex'       { if (Test-Path (Join-Path $ProjectPath 'AGENTS.md'))     { $hits += 'AGENTS.md' } }
        'openclaw'    { if (Test-Path (Join-Path $ProjectPath 'skills'))         { $hits += 'skills/' } }
        'raw'         { if (Test-Path (Join-Path $ProjectPath 'docs\ai-rules')) { $hits += 'docs/ai-rules/' } }
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

function Install-Cursor {
    param([string[]]$SkillList, [string]$ProjectPath)

    $rulesDir = Join-Path $ProjectPath '.cursor\rules'
    Write-Host "`nInstalling to $rulesDir`n" -ForegroundColor Cyan

    foreach ($skill in $SkillList) {
        $name = ($skill -split '/')[-1]
        $src = Join-Path $PromptsRoot ($skill -replace '/', '\') | Join-Path -ChildPath 'SKILL.md'
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        $dest = Join-Path $rulesDir "$name.md"
        Copy-SkillToFile -SrcPath $src -DestPath $dest
    }

    Write-Host "`nDone. Reload your Cursor window to pick up the new rules." -ForegroundColor Cyan
    Write-Host "Tip: open a rule file and add 'alwaysApply: true' to the frontmatter for always-on rules." -ForegroundColor DarkGray
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

function Install-Codex {
    param([string[]]$SkillList, [string]$ProjectPath)

    $agentsFile = Join-Path $ProjectPath 'AGENTS.md'
    Write-Host "`nBuilding $agentsFile from $($SkillList.Count) skills`n" -ForegroundColor Cyan

    if ($DryRun) {
        $verb = if (Test-Path $agentsFile) { 'replace' } else { 'create' }
        Write-Host "  [dry-run] would $verb $agentsFile from $($SkillList.Count) skills" -ForegroundColor DarkCyan
        return
    }

    if ((Test-Path $agentsFile) -and -not $Force) {
        $resp = Read-Host "$agentsFile exists. Overwrite? [y/N]"
        if ($resp -notmatch '^[yY]') { Write-Host "Aborted." -ForegroundColor Yellow; return }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Agent Instructions')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Generated by prompt-pack install.ps1. Do not edit by hand; re-run the')
    [void]$sb.AppendLine('installer to update. Source: https://github.com/Ozzeron/prompt-pack')
    [void]$sb.AppendLine()

    $totalBytes = $sb.Length
    $sizeLimit = 32 * 1024  # Codex limit
    $included = @()
    $skipped = @()

    foreach ($skill in $SkillList) {
        $src = Join-Path $PromptsRoot ($skill -replace '/', '\') | Join-Path -ChildPath 'SKILL.md'
        if (-not (Test-Path $src)) { Write-Host "  Missing: $src" -ForegroundColor Red; continue }

        $body = Get-SkillBody -SrcPath $src
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
        Write-Host "`nTip: pick a smaller profile or use directory-specific AGENTS.override.md files." -ForegroundColor DarkGray
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
    'cursor'      { Install-Cursor      -SkillList $skillList -ProjectPath $projectPath }
    'claude-code' { Install-ClaudeCode  -SkillList $skillList -ProjectPath $projectPath }
    'codex'       { Install-Codex       -SkillList $skillList -ProjectPath $projectPath }
    'openclaw'    { Install-OpenClaw    -SkillList $skillList -ProjectPath $projectPath }
    'raw'         { Install-Raw         -SkillList $skillList -ProjectPath $projectPath }
}
