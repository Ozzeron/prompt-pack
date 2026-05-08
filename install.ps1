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

    $destDir = Split-Path $DestPath -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

    if ((Test-Path $DestPath) -and -not $Force) {
        $resp = Read-Host "  Overwrite $DestPath? [y/N]"
        if ($resp -notmatch '^[yY]') { Write-Host "  Skipped." -ForegroundColor Yellow; return }
    }

    Copy-Item -Path $SrcPath -Destination $DestPath -Force
    Write-Host "  Wrote $DestPath" -ForegroundColor Green
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
        if ((Test-Path $dest) -and -not $Force) {
            $resp = Read-Host "  Overwrite $dest? [y/N]"
            if ($resp -notmatch '^[yY]') { Write-Host "  Skipped." -ForegroundColor Yellow; continue }
            Remove-Item -Path $dest -Recurse -Force
        }

        Copy-Item -Path $src -Destination $dest -Recurse -Force
        Write-Host "  Wrote $dest" -ForegroundColor Green
    }

    Write-Host "`nDone." -ForegroundColor Cyan
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

switch ($Target) {
    'cursor'      { Install-Cursor      -SkillList $skillList -ProjectPath $projectPath }
    'claude-code' { Install-ClaudeCode  -SkillList $skillList -ProjectPath $projectPath }
    'codex'       { Install-Codex       -SkillList $skillList -ProjectPath $projectPath }
    'openclaw'    { Install-OpenClaw    -SkillList $skillList -ProjectPath $projectPath }
    'raw'         { Install-Raw         -SkillList $skillList -ProjectPath $projectPath }
}
