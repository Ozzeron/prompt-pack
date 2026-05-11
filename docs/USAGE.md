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

The installer supports six targets. Pick one based on your AI tool:

| Target        | Output location | Tool |
|---------------|----------------|------|
| `cursor`      | `<project>/.cursor/rules/` | Cursor IDE |
| `claude-code` | `<project>/.claude/agents/` | Claude Code |
| `codex`           | `<project>/.agents/skills/<name>/SKILL.md` + compact `<project>/AGENTS.md` | OpenAI Codex CLI / IDE / app (native skills format) |
| `codex-agents-md` | `<project>/AGENTS.md` (single merged file) | Legacy Codex installs without `.agents/skills/` support |
| `openclaw`    | `<project>/skills/<name>/` (full directories) | OpenClaw workspace |
| `raw`         | `<project>/docs/ai-rules/` (frontmatter-stripped) | ChatGPT, Claude.ai, any tool that takes a system prompt |

## Profiles

Don't pick skills one at a time — pick a profile and adjust later:

| Profile     | Count | Includes |
|-------------|-------|----------|
| `minimal`   | 4 | `engineering-principles`, `reuse-before-create`, `token-discipline`, `handoff` |
| `nextjs`    | 10 | `minimal` + frontend-feature, ui-designer, code-review, repo-audit, debugger, test-writer |
| `backend`   | 13 | `minimal` + backend-api, database-schema, database-migrations, code-review, repo-audit, database-review, security-review, debugger, test-writer |
| `supabase`  | 14 | `backend` + postgres-supabase |
| `fullstack` | 21 | Almost every skill except niche audits |
| `all`       | 23 | Every skill in the pack |

Custom selection works too — see "Picking specific skills" below.

## Cursor

Cursor reads project-local rules from `.cursor/rules/*.mdc`. The installer
generates these as proper Cursor Project Rules with the Cursor-native
frontmatter fields (`description`, `globs`, `alwaysApply`); your generic
`triggers` and `applies_to` are not read by Cursor.

```bash
cd ~/code/your-project
~/code/prompt-pack/install.sh --target cursor --profile nextjs
```

```powershell
cd ~\code\your-project
& ~\code\prompt-pack\install.ps1 -Target cursor -Profile nextjs
```

Reload the Cursor window (`Cmd/Ctrl+Shift+P` → `Reload Window`) to pick up
the new rules.

### How rules activate on Cursor

The installer assigns activation modes automatically. Cursor supports four
modes; the installer maps them like this:

- **Always Apply (`alwaysApply: true`)** — the meta layer that the pack
  inherits everywhere: `engineering-principles`, `reuse-before-create`,
  `token-discipline`, `task-router`. Plus a small `prompt-pack-router.mdc`
  bridge file that names the routing table and multilingual aliases. These
  load on every turn. Keep this set small — anything else here eats context
  unnecessarily.
- **Agent Requested** (`alwaysApply: false`, no `globs`) — every other skill.
  Cursor decides whether to load the rule based on the `description` field
  matching the user's request. This is best-effort and **not guaranteed**
  to fire on every relevant request. For critical workflows, invoke the
  rule explicitly.
- **Auto Attached** (`globs:`) — not used by the installer by default. Add
  globs manually if you want a rule to load whenever certain files are in
  context (e.g. set `globs: ["**/*.tsx", "**/*.ts"]` on `frontend-feature`
  for a TypeScript codebase).
- **Manual** — invoke any rule explicitly with `@<rule-name>` in chat. This
  is the **most reliable** mode; prefer it for code review, security review,
  audit, and other workflows where you want the discipline to actually run.

### Recommended usage in chat

For critical work, invoke explicitly:

```
@code-review review the diff in PR #42
@security-review audit the new upload endpoint
@repo-audit check the whole project
@frontend-feature build a settings page for user preferences
```

The `prompt-pack-router.mdc` bridge file (always loaded) gives the agent
the routing table and recognises Russian and Ukrainian intent aliases
("проревьюй весь проект" → `@repo-audit`, etc.). It improves
auto-routing but does not replace explicit `@<rule-name>` for critical
workflows.

### Customising activation

If you want a rule to behave differently — for example, make
`code-review` always-on instead of agent-requested — open the generated
`.cursor/rules/<name>.mdc` and edit the frontmatter:

```yaml
---
description: Review a diff or pull request...
globs: ["**/*.ts", "**/*.tsx"]    # optional: load when these files in context
alwaysApply: false                # change to true for always-on
---
```

Reinstalling with `--force` will overwrite your edits and back up the
prior version with a `.bak-<timestamp>` suffix.

### Recommended `.gitignore` for Cursor target

The `--force` reinstall path leaves `<rule>.mdc.bak-<timestamp>` files
behind so your customisations are recoverable. They accumulate in
`.cursor/rules/` and pollute the directory listing in your editor and
in diffs. Add the following to your project's `.gitignore` (the pack
does not commit a `.gitignore` into your project on install):

```gitignore
# prompt-pack reinstall backups (created by install.{sh,ps1} --force)
.cursor/rules/*.bak-*
```

### Verification checklist (post-install sanity check)

After a Cursor install you can confirm the rules landed correctly with
three quick checks. Useful when contributing a new skill or when
debugging "why isn't my rule firing".

```bash
# 1. Count generated rule files (skills + 1 bridge router).
#    On `fullstack` profile, expect 22 (21 skills + bridge).
ls .cursor/rules/*.mdc | wc -l

# 2. Count alwaysApply: true rules. Should be 5 on fullstack:
#    engineering-principles, reuse-before-create, token-discipline,
#    task-router, and the prompt-pack-router bridge.
grep -l 'alwaysApply: true' .cursor/rules/*.mdc | wc -l

# 3. Confirm the Mandatory routes section is present in the bridge.
grep -c '^## Mandatory routes' .cursor/rules/prompt-pack-router.mdc
# (or its English variant)
grep -c 'Mandatory routes' .cursor/rules/prompt-pack-router.mdc
```

PowerShell equivalents:

```powershell
# 1. File count
(Get-ChildItem .cursor/rules/*.mdc).Count

# 2. Always-apply count
(Select-String -Path .cursor/rules/*.mdc -Pattern 'alwaysApply: true' -List).Count

# 3. Mandatory routes presence
(Select-String -Path .cursor/rules/prompt-pack-router.mdc -Pattern 'Mandatory routes').Count
```

If any of the three returns an unexpected number, reinstall with
`--force` to refresh. If the counts stay wrong after a fresh install,
file an issue with the profile name and the actual numbers.

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

For repo-wide context (conventions, do-not-touch zones, test commands), Claude Code
reads `CLAUDE.md` first, falling back to `AGENTS.md` when no `CLAUDE.md` is present.
The `codex` target writes a *compact router-bridge* AGENTS.md plus a tree under
`.agents/skills/` — useful for Codex but not what you want for Claude Code's repo
doc. To get a single self-contained file you can rename to `CLAUDE.md`, use the
legacy `codex-agents-md` target, which concatenates the selected skills into one
markdown blob:

```bash
~/code/prompt-pack/install.sh --target codex-agents-md --profile minimal
mv AGENTS.md CLAUDE.md   # Claude Code prefers this filename
```

## OpenAI Codex CLI

Codex has two distinct mechanisms, and prompt-pack maps to both:

1. **Skills** (`.agents/skills/<name>/SKILL.md`) — reusable workflows. Codex
   uses *progressive disclosure*: it reads only `name` + `description` for
   the initial list, and loads the full `SKILL.md` only when it picks the
   skill. Lookup roots: `<repo>/.agents/skills/`, walk-up from CWD to repo
   root, plus `$HOME/.agents/skills/` (user) and `/etc/codex/skills/`
   (admin). See [Codex skills docs](https://developers.openai.com/codex/skills).
2. **AGENTS.md** — project guidance chain. Codex reads `~/.codex/AGENTS.md`
   (global), then walks from repo root down to your CWD picking up
   `AGENTS.md` / `AGENTS.override.md` at each level, capped at 32 KiB total.
   See [Codex AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md).

The `codex` target writes each skill as a folder under `.agents/skills/`
(the native format) and emits a compact `AGENTS.md` (~2 KB) at the project
root containing the routing table and multilingual intent aliases. Skill
bodies stay in their folders, so the AGENTS.md budget is left almost
entirely free for project-specific guidance.

### Per-project install (most common)

```bash
cd ~/code/your-project
~/code/prompt-pack/install.sh --target codex --profile supabase
```

Result:

```
your-project/
  .agents/skills/
    code-review/SKILL.md
    repo-audit/SKILL.md
    ...
  AGENTS.md         # compact router + multilingual aliases
```

### User scope (apply to every Codex session)

For skills you want available regardless of the working directory:

```bash
~/code/prompt-pack/install.sh --target codex --scope user --profile minimal
```

This writes to `$HOME/.agents/skills/`. No `AGENTS.md` is written in this
mode — user-scope `AGENTS.md` belongs at `~/.codex/AGENTS.md` and is your
project-independent guidance, not a place for skill content.

### Activating skills

- **Explicit**: type `$<skill-name>` in a Codex prompt, e.g. `$code-review`.
- **Implicit**: Codex matches the skill `description` against the task.
  Concise, scope-bounded descriptions trigger more reliably.

Restart Codex after installing so it rescans the discovery roots.

### Verify it loaded

```bash
codex --ask-for-approval never "List the prompt-pack skills you can use."
```

### Legacy single-file mode (codex-agents-md)

Older Codex installs (or hosts that don't yet support `.agents/skills/`)
need everything in a single `AGENTS.md`. Use the legacy target only in
that case:

```bash
~/code/prompt-pack/install.sh --target codex-agents-md --profile minimal
```

The combined file is capped at 32 KiB (`project_doc_max_bytes` default);
skills that would push it over are skipped with a notice. Switch to the
native `codex` target as soon as you can — it removes the size cap because
skills load on demand.

### Directory-specific overrides

If a sub-tree of your project needs different rules (e.g. `services/payments`
uses a different test command), add a manual
`services/payments/AGENTS.override.md` with just the override content. Codex
merges from root → cwd, with closer files winning.

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
