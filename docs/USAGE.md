# Usage

How to install and use `prompt-pack` skills with each major AI coding tool. The pack
ships with `install.sh` (bash) and `install.ps1` (PowerShell) — one command per project.

## Prerequisites

Clone the pack once anywhere on your machine:

```bash
git clone https://github.com/Ozzeron/prompt-pack.git ~/code/prompt-pack
```

That's the source. Updates: `cd ~/code/prompt-pack && git pull`, then re-run the installer
in projects where you want the latest.

## Targets

The installer supports five targets. Pick one based on your AI tool:

| Target        | Output location | Tool |
|---------------|----------------|------|
| `cursor`      | `<project>/.cursor/rules/` | Cursor IDE |
| `claude-code` | `<project>/.claude/agents/` | Claude Code |
| `codex`       | `<project>/AGENTS.md` (single merged file) | OpenAI Codex CLI |
| `openclaw`    | `<project>/skills/<name>/` (full directories) | OpenClaw workspace |
| `raw`         | `<project>/docs/ai-rules/` (frontmatter-stripped) | ChatGPT, Claude.ai, any tool that takes a system prompt |

## Profiles

Don't pick skills one at a time — pick a profile and adjust later:

| Profile     | Count | Includes |
|-------------|-------|----------|
| `minimal`   | 4 | `engineering-principles`, `reuse-before-create`, `token-discipline`, `handoff` |
| `nextjs`    | 9 | `minimal` + frontend-feature, ui-designer, code-review, debugger, test-writer |
| `backend`   | 12 | `minimal` + backend-api, database-schema, database-migrations, code-review, database-review, security-review, debugger, test-writer |
| `supabase`  | 13 | `backend` + postgres-supabase |
| `fullstack` | 18 | Almost every skill except niche audits |
| `all`       | 21 | Every skill in the pack |

Custom selection works too — see "Picking specific skills" below.

## Cursor

Cursor reads project-local rules from `.cursor/rules/*.md`. Each rule has YAML frontmatter
that controls when it activates.

```bash
cd ~/code/your-project
~/code/prompt-pack/install.sh --target cursor --profile nextjs
```

```powershell
cd ~\code\your-project
& ~\code\prompt-pack\install.ps1 -Target cursor -Profile nextjs
```

Reload the Cursor window (`Cmd/Ctrl+Shift+P` → `Reload Window`) to pick up the new rules.

### Always-on rules

Some rules should apply to every file (engineering principles, reuse, token discipline).
Open the copied file in `.cursor/rules/` and edit the frontmatter:

```yaml
---
name: engineering-principles
alwaysApply: true     # add this line
description: ...
---
```

### Path-scoped rules

For rules that should only apply to specific files (e.g. `frontend-feature` only for
`.tsx`):

```yaml
---
name: frontend-feature
globs: ["**/*.tsx", "**/*.ts"]
description: ...
---
```

### Using rules in chat

In Cursor's agent chat you can reference a rule by name:

```
@frontend-feature build a settings page for user preferences
```

## Claude Code

Claude Code picks up subagents from `.claude/agents/*.md` automatically. Description
matching activates the right subagent for the task.

```bash
cd ~/code/your-project
~/code/prompt-pack/install.sh --target claude-code --profile fullstack
```

```powershell
cd ~\code\your-project
& ~\code\prompt-pack\install.ps1 -Target claude-code -Profile fullstack
```

No reload needed — Claude Code reads `.claude/agents/` on each invocation.

### Repository-wide context

For repo-wide context (conventions, do-not-touch zones, test commands), Claude Code reads
`CLAUDE.md` first. To generate one from the pack, use the `codex` target — Claude Code
also reads `AGENTS.md` if `CLAUDE.md` is absent:

```bash
~/code/prompt-pack/install.sh --target codex --profile minimal
mv AGENTS.md CLAUDE.md   # if you prefer the Claude-specific name
```

## OpenAI Codex CLI

Codex CLI reads `AGENTS.md` files in three layers and merges them:
1. `~/.codex/AGENTS.md` — global, applies everywhere
2. `<repo>/AGENTS.md` — per-project
3. `<repo>/<dir>/AGENTS.md` or `AGENTS.override.md` — per-directory

The installer's `codex` target builds a single merged `AGENTS.md` at the path you point
it to. The combined file size respects Codex's 32 KB limit; skills that would push it
over are skipped with a notice.

### Per-project (most common)

```bash
cd ~/code/your-project
~/code/prompt-pack/install.sh --target codex --profile supabase
```

### Global (apply to every project)

```bash
mkdir -p ~/.codex
~/code/prompt-pack/install.sh --target codex --profile minimal --path ~/.codex
```

### Verify it loaded

```bash
codex --ask-for-approval never "Summarize the current instructions."
```

### Directory-specific overrides

If a sub-tree of your project needs different rules (e.g. `services/payments` uses a
different test command), add a manual `services/payments/AGENTS.override.md` with just
the override content. Codex merges from root → cwd, with closer files winning.

## OpenClaw

OpenClaw reads skill directories from its workspace `skills/` folder. Each skill is a
directory with `SKILL.md` plus optional supporting files.

```bash
~/code/prompt-pack/install.sh --target openclaw --profile fullstack --path ~/.openclaw/workspace
```

```powershell
& ~\code\prompt-pack\install.ps1 -Target openclaw -Profile fullstack -Path ~\.openclaw\workspace
```

### ClawHub (per-skill)

Once a skill is published to the ClawHub registry, install it by slug instead:

```bash
clawhub install <skill-slug>
```

Publication status is tracked in each skill's `CHANGELOG.md`. Most skills are not
published yet — use the local installer for now.

## ChatGPT, Claude.ai, any other AI tool

Use the `raw` target. It strips YAML frontmatter and writes the prompt body to
`docs/ai-rules/<name>.md`. Paste the body into:

- ChatGPT: a custom GPT's Instructions, or a project's instructions
- Claude.ai: project Custom Instructions
- Any other tool: its system-prompt or persistent-instruction field

```bash
~/code/prompt-pack/install.sh --target raw --profile minimal
cat docs/ai-rules/engineering-principles.md   # then copy-paste
```

## Picking specific skills

If a profile doesn't fit, pass skills explicitly:

```bash
./install.sh --target cursor \
  --skill meta/engineering-principles \
  --skill meta/reuse-before-create \
  --skill architecture/frontend-feature \
  --skill review/debugger
```

```powershell
.\install.ps1 -Target cursor -Skills `
  meta/engineering-principles, `
  meta/reuse-before-create, `
  architecture/frontend-feature, `
  review/debugger
```

## Listing what's available

```bash
./install.sh --list
```

```powershell
.\install.ps1 -List
```

Shows all profiles, all skills, and all targets.

## Recommended starter set

Don't install everything on day one. Start with `minimal` to set the engineering
baseline, then add task-specific skills as you hit those tasks.

After a week of real use, audit which rules actually trigger value vs. which sit dead.
Remove the dead ones. The pack is a buffet, not an obligation.

## Updating

```bash
cd ~/code/prompt-pack && git pull
cd ~/code/your-project
~/code/prompt-pack/install.sh --target cursor --profile minimal --force
```

`--force` skips the per-file overwrite prompt. The installer is idempotent — re-running
it overwrites with the latest version of each skill.

## Safety and reversibility

The installer only touches agent-config locations. It never modifies your application
code. Even so, treat it like any third-party script in your project:

### Safe first run

```bash
cd ~/code/your-project
~/code/prompt-pack/install.sh --target cursor --profile minimal --dry-run   # preview
~/code/prompt-pack/install.sh --target cursor --profile minimal             # interactive
```

```powershell
cd ~\code\your-project
& ~\code\prompt-pack\install.ps1 -Target cursor -Profile minimal -DryRun
& ~\code\prompt-pack\install.ps1 -Target cursor -Profile minimal
```

The installer runs pre-flight checks and warns when:

- Agent-config already exists at the target location (`.cursor/rules/`,
  `.claude/agents/`, `AGENTS.md`, `skills/`, `docs/ai-rules/`)
- The git working tree is dirty (so you can review changes via `git diff` afterwards)
- The directory isn't a git repo (so undoing requires manual deletion)

### `--dry-run` (preview without writing)

Reports every file or directory that **would** be created or replaced. No filesystem
changes. Use this on every first install or before a profile change.

### `--force` (non-interactive)

Replaces existing **files** without prompting. For existing **directories** (only used by
the `openclaw` target), the installer **never deletes them outright** — it renames them
to `<name>.bak-<timestamp>` first, then writes the new version. Backups stay until you
remove them yourself.

```
skills/
  engineering-principles/                   # current
  engineering-principles.bak-20260508-150622/  # previous, kept until you delete it
```

Delete `.bak-*` directories once you've confirmed the new install works.

### Recommended first-run flow

1. Make sure your working tree is clean: `git status`
2. Preview: `--dry-run` with the target/profile you want
3. Real run: drop `--dry-run`, keep interactive prompts (no `--force`)
4. Review: `git diff` and `git status`
5. If wrong: `git checkout .` and `git clean -fd .cursor .claude AGENTS.md skills docs/ai-rules`
   (or whichever target you used)

For automated re-installs (CI, dotfile setup, repo provisioning), `--force` is the
intended mode. The directory-backup behaviour means it's still safe.
