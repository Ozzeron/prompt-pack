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

The installer supports ten targets. Pick one based on your AI tool.

**Two carry the pack forward:** `claude-skills` (or the Claude Code plugin, below) and
`agents` for Cursor / Codex / Copilot / OpenClaw. The rest exist for hosts that predate Agent Skills —
maintained, not developed.

**Directory targets vs flat targets.** Skills keep on-demand material in
`references/*.md` (output templates, coverage passes, worked examples), loaded only when the
skill's own instructions call for it. Targets that write a directory per skill —
`claude-skills`, `agents`, `cursor`, `codex`, `openclaw`, and the plugin — copy those files
verbatim. Flat targets write a single file per skill and **cannot carry them**:
`cursor-rules`, `codex-agents-md`, `claude-code` (subagents), and `raw` lose the referenced
files, so a skill installed that way still names its reference file but the file is not
there. Prefer a directory target unless your host forces otherwise.

| Target            | Output location | Tool |
|-------------------|----------------|------|
| `cursor`          | `<project>/.cursor/skills/<name>/SKILL.md` (most skills) + `<project>/.cursor/rules/*.mdc` (foundation rules) | Cursor 2.4+ (Skills-native) |
| `cursor-foundation` | `<project>/.cursor/rules/*.mdc` (three foundation rules only, no `.cursor/skills/`) | Cursor 2.4+ — pair with `agents` to avoid duplicate skill roots |
| `cursor-rules`    | `<project>/.cursor/rules/*.mdc` (every skill + bridge router) | Cursor builds older than 2.4 / rules-only flow |
| `agents`          | `<project>/.agents/skills/<name>/SKILL.md` (no AGENTS.md) | Cursor 2.4+, Codex CLI, GitHub Copilot, OpenClaw — one install for all four |
| `claude-skills`   | `<project>/.claude/skills/<name>/SKILL.md` (or `~/.claude/skills/` with `--scope user`) | Claude Code (native Agent Skills) |
| `claude-code`     | `<project>/.claude/agents/` | Claude Code (legacy subagents — prefer `claude-skills`) |
| `codex`           | `<project>/.agents/skills/<name>/SKILL.md` + compact `<project>/AGENTS.md` | OpenAI Codex CLI / IDE / app (native skills format) |
| `codex-agents-md` | `<project>/AGENTS.md` (single merged file) | Legacy Codex installs without `.agents/skills/` support |
| `openclaw`        | `<project>/skills/<name>/` (full directories) | OpenClaw workspace |
| `raw`             | `<project>/docs/ai-rules/` (frontmatter-stripped) | ChatGPT, Claude.ai, any tool that takes a system prompt |

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

## Cursor 2.4+

The `cursor` target is **Skills-native** for Cursor 2.4 and newer. Cursor 2.4
added first-class Agent Skills discovery at `.cursor/skills/<name>/SKILL.md`
(and `.agents/skills/<name>/SKILL.md` as a fallback). Cursor reads only the
`name` + `description` frontmatter to populate its skill list, then loads
the body on demand — same progressive-disclosure model as Codex.

The installer splits the install:

- **Foundation rules** (`engineering-principles`, `reuse-before-create`,
  `token-discipline`) go to `.cursor/rules/*.mdc` with `alwaysApply: true`.
  These need to be in scope on every turn, and Cursor Agent Skills are
  agent-requested by default — there is no `alwaysApply` for Skills.
- **Every non-foundation skill except `meta/task-router`** goes to
  `.cursor/skills/<name>/SKILL.md` as a Cursor Agent Skill folder.
  `meta/task-router` is filtered out — native Cursor Skills discovery
  replaces the routing role it played in the legacy rules flow.

The legacy `prompt-pack-router.mdc` bridge file is **not installed** by the
Skills-native target — native Skills discovery replaces it.

```bash
cd ~/code/your-project
~/code/prompt-pack/install.sh --target cursor --profile nextjs
```

```powershell
cd ~\code\your-project
& ~\code\prompt-pack\install.ps1 -Target cursor -Profile nextjs
```

Reload the Cursor window (`Cmd/Ctrl+Shift+P` → `Reload Window`) to pick up
the new skills.

### Migrating from the legacy rules-only install

If you previously installed with the rules-only flow (everything in
`.cursor/rules/*.mdc`, including the `prompt-pack-router.mdc` bridge),
the new `cursor` target is a one-shot migration: re-running the installer
is the `/migrate-to-skills` step. You have two options:

1. **Clean migrate (recommended).** Move the old generated `.mdc` files
   to a backup folder, then re-run with the new target:

   ```bash
   # WARNING: only run this if .cursor/rules/ contains ONLY prompt-pack
   # generated files. If you have hand-written project rules in there,
   # move them out first, or skip this step entirely and let the installer
   # interactively prompt on each overwrite.
   mkdir -p .cursor/rules.bak && mv .cursor/rules/*.mdc .cursor/rules.bak/
   ~/code/prompt-pack/install.sh --target cursor --profile <your-profile>
   ```

   The installer keeps the three foundation rules in `.cursor/rules/` and
   moves everything else to `.cursor/skills/`. If you had hand-edited any
   rule, copy those changes over before re-running. `mv` to a backup
   folder (vs. `rm -rf`) means a mistake here is recoverable.

2. **Stay on the rules-only flow.** Use the legacy `cursor-rules` target
   instead (see below). Functionally identical to the pre-v0.4 `cursor`
   target, including the `prompt-pack-router.mdc` bridge.

### How skills activate on Cursor 2.4+

- **Foundation rules** (`.cursor/rules/*.mdc`, `alwaysApply: true`) load on
  every turn. Keep this set small — anything else here eats context.
- **Agent Skills** (`.cursor/skills/<name>/SKILL.md`) are picked up by
  Cursor's native skill matcher based on the `description` frontmatter
  field. Concise, scope-bounded descriptions trigger more reliably.
- **Manual invocation** still works: type `/` in Agent chat and search
  for the skill name (e.g. `/code-review`, `/security-review`). Prefer
  this for critical workflows. Note: `@<rule-name>` belongs to the legacy
  `cursor-rules` flow — for Skills-native `cursor` target use `/skill-name`.
- **Legacy cursor-rules**: use `@<rule-name>` for explicit invocation
  (agent-requested rules via `@rule-name`).

### Recommended usage in chat

For critical work, invoke explicitly via the slash menu (`/` in Agent chat):

```
/code-review review the diff in PR #42
/security-review audit the new upload endpoint
/repo-audit check the whole project
/frontend-feature build a settings page for user preferences
```

> **Note:** `@skill-name` invocation belongs to the legacy `cursor-rules` flow.
> For the Skills-native `cursor` target, use `/skill-name` or the slash menu.

### Recommended `.gitignore` for the Cursor target

The `--force` reinstall path leaves backups behind so your customisations
are recoverable. Add the following to your project's `.gitignore`:

```gitignore
# prompt-pack reinstall backups (created by install.{sh,ps1} --force)
.cursor/rules/*.bak-*
.cursor/skills/*.bak-*
```

### Verification checklist (post-install sanity check)

After installing `cursor`, you can confirm the layout with:

```bash
# 1. Foundation rules in .cursor/rules/ — expect exactly 3 (engineering-principles,
#    reuse-before-create, token-discipline). No prompt-pack-router.mdc here.
ls .cursor/rules/*.mdc | wc -l

# 2. Skills in .cursor/skills/ — count = (profile size) - 3 foundation rules.
ls -d .cursor/skills/*/ | wc -l

# 3. No legacy bridge file.
test -f .cursor/rules/prompt-pack-router.mdc && echo 'WARN: legacy bridge still present'
```

PowerShell equivalents:

```powershell
(Get-ChildItem .cursor/rules/*.mdc).Count             # 3
(Get-ChildItem .cursor/skills -Directory).Count       # profile size - 3
Test-Path .cursor/rules/prompt-pack-router.mdc        # False
```

## Cursor (legacy: `cursor-rules`)

For Cursor builds older than 2.4, or if you specifically prefer the
rules-only flow, use the `cursor-rules` target. This is the pre-v0.4
behaviour: every skill becomes a `.cursor/rules/<name>.mdc` Project Rule,
and a `prompt-pack-router.mdc` bridge file is added as an always-apply
rule.

```bash
~/code/prompt-pack/install.sh --target cursor-rules --profile nextjs
```

```powershell
& ~\code\prompt-pack\install.ps1 -Target cursor-rules -Profile nextjs
```

In this mode the `meta/task-router` skill is also marked `alwaysApply: true`
because the rules-only flow has no Skills discovery to fall back on.

## Universal Agent Skills (`agents`)

The `agents` target writes every skill to `.agents/skills/<name>/SKILL.md`
with no AGENTS.md bridge. This layout is read by Cursor 2.4+, Codex CLI,
GitHub Copilot, and OpenClaw — one install for all four. On Copilot that covers the
coding agent, code review, the CLI, and agent mode in VS Code and JetBrains (agent
skills reached GA in Copilot code review on 2026-07-29).

```bash
~/code/prompt-pack/install.sh --target agents --profile fullstack
```

```powershell
& ~\code\prompt-pack\install.ps1 -Target agents -Profile fullstack
```

**No always-apply rules** are installed in this mode, on purpose:
`.agents/skills/` is a skill-only layout, and adding a `.cursor/rules/`
side-channel would couple the target to Cursor. If you need always-on
foundation rules in Cursor, layer the **`cursor-foundation`** target on
top — see [Layering for Cursor users](#layering-for-cursor-users) below.
For Codex, inline the engineering-principles content into your `AGENTS.md`
manually.

Use `agents` when you want Codex + Cursor + Copilot + OpenClaw all activated from a
single install with no AGENTS.md noise. Use `codex` when you specifically
want the Codex AGENTS.md router (multilingual aliases, routing table).

`meta/task-router` is filtered out of this target's skill list (and out of
`claude-skills`): it's written for the OpenClaw / Claude Code
subagent-orchestration model and fights the hosts' native skill matchers.
The legacy `cursor-rules` and OpenClaw / Claude Code / Codex targets keep it.

### One skill root per repo (who reads what, September 2026)

Every native host now scans more than one directory, and several of them overlap. This is
what each host discovers at project level, from the vendors' own docs:

| Host | Project roots it scans | User roots |
|---|---|---|
| Cursor | `.agents/skills/`, `.cursor/skills/`, `.claude/skills/`, `.codex/skills/` | `~/.agents/skills/`, `~/.cursor/skills/`, `~/.claude/skills/`, `~/.codex/skills/` |
| Codex | `.agents/skills/` (CWD, parents, repo root) | `~/.agents/skills/`, `/etc/codex/skills/` |
| GitHub Copilot | `.github/skills/`, `.claude/skills/`, `.agents/skills/` | `~/.copilot/skills/`, `~/.agents/skills/` |
| Claude Code | `.claude/skills/` (plus nested and `--add-dir` copies) | `~/.claude/skills/`, plugins |
| OpenClaw | `<workspace>/skills/`, `<workspace>/.agents/skills/` | `~/.agents/skills/` |

The consequence: **install exactly one skill root per repo.** `.agents/skills/` is the only
directory every non-Claude host reads, which is why `agents` is the universal target. Mixing
roots duplicates skills in whichever host reads both: `claude-skills` + `agents` shows every
skill twice in Cursor *and* in Copilot, `codex` + `cursor` doubles them in Cursor, and a
`.claude/skills/` tree vendored for Claude Code teammates is also picked up by Cursor and
Copilot on the same machine. If your team uses Claude Code alongside Cursor or Copilot, put
the pack in `.agents/skills/` and give Claude Code the plugin (user scope, not in the repo).

### Layering for Cursor users

Do **not** install `agents` and `cursor` together in the same repo. Cursor
reads both `.agents/skills/` and `.cursor/skills/`, so each skill would
show up twice in the skill list (once from each tree), and Cursor's
matcher would have to break the tie at runtime. That's noise you don't
want.

Pick one of the following layouts:

- **Cursor-only project**: use `--target cursor`. Writes to
  `.cursor/skills/` for most skills + `.cursor/rules/*.mdc` for the three
  foundation rules.
- **Universal (Cursor + Codex + Copilot + OpenClaw)**: use `--target agents`. Writes
  only `.agents/skills/`. No always-apply foundation rules anywhere.
- **Universal + always-on foundation rules in Cursor**: combine
  `--target agents` (specialised skills) with `--target cursor-foundation`
  (3 alwaysApply `.cursor/rules/*.mdc` files only, no `.cursor/skills/`).
  The two trees do not overlap, so no duplication.

> **`codex` + `cursor` in the same repo (Cursor as IDE):** The `codex`
> target writes to `.agents/skills/`; the `cursor` target writes to
> `.cursor/skills/`. Cursor 2.4+ reads **both** trees, so every skill
> appears twice. If you need both Codex CLI and Cursor support, use
> `--target agents` (+ optionally `cursor-foundation`) instead of mixing
> `codex` and `cursor`.
> If you intentionally keep both targets, add `.cursor/skills/` to
> `.gitignore` so only `.agents/skills/` is tracked as the source of truth.
>
> **For AI agents:** if `.agents/skills/` already exists in this repo
> (from a `codex` install), do **not** run `--target cursor` — it creates
> duplicate skill roots that Cursor reads simultaneously. Preferred combo:
> `--target agents` + `--target cursor-foundation`.

```bash
# Layered combo: skills + always-on Cursor foundation rules.
~/code/prompt-pack/install.sh --target agents            --profile fullstack
~/code/prompt-pack/install.sh --target cursor-foundation --profile fullstack
```

```powershell
& ~\code\prompt-pack\install.ps1 -Target agents            -Profile fullstack
& ~\code\prompt-pack\install.ps1 -Target cursor-foundation -Profile fullstack
```

The `cursor-foundation` target ignores any non-foundation skills in the
profile, so you can pass the same `--profile fullstack` to both commands
and each writes only what belongs in its tree.

## Claude Code

Claude Code supports Agent Skills natively: each skill is a directory with a
`SKILL.md` under `.claude/skills/` (project) or `~/.claude/skills/` (user).
Claude reads `name` + `description` from the frontmatter to decide relevance
and loads the full skill on selection — same progressive-disclosure model as
Cursor 2.4+ and Codex.

### Plugin marketplace (recommended — no clone needed)

The repo doubles as a Claude Code plugin marketplace
(`.claude-plugin/marketplace.json`). Add it once and install a profile plugin:

```
/plugin marketplace add Ozzeron/prompt-pack
/plugin install fullstack@prompt-pack
```

One plugin per installer profile: `minimal`, `nextjs`, `backend`, `supabase`,
`fullstack`, `all-skills`. The profiles overlap by design (each includes the
minimal core), so install exactly ONE — two profile plugins side by side would
duplicate the shared skills in discovery. Switch profiles with
`/plugin uninstall` + `/plugin install`; update with `/plugin update`.
Plugins install to user scope by default and work across all your projects.

`meta/task-router` is excluded from every plugin — Claude Code's native skill
discovery does the routing. Note that Claude Code ships built-in `/code-review`
and `/security-review` commands; the pack's same-named skills coexist under the
plugin namespace but you may prefer a profile without them if you find the
overlap noisy.

#### Enforcement hooks (optional, layer on any profile)

```
/plugin install enforcement@prompt-pack
```

This plugin installs **no skills**. It registers three `PreToolUse` hooks that make three of
the pack's own rules deterministic instead of advisory:

| Guard | Rule it enforces | Behaviour |
|---|---|---|
| `guard-noise-reads` | `meta/token-discipline` | **denies** reads of `node_modules/`, git internals, lockfiles, minified bundles; **asks** on build output (`dist/`, `.next/`, `coverage/`) where a read is sometimes legitimate |
| `guard-new-file` | `meta/reuse-before-create` | **asks** when a new source file duplicates an existing name modulo case, separators, and extension |
| `guard-new-dependency` | `meta/engineering-principles` | **asks** when an install command names a package; restore commands (`npm ci`, `pnpm install`) pass through |

Every guard fails open: a malformed payload or an internal error exits with no decision, so
a bug can never block your work. They make no network calls and write no files. This is the
only part of the pack that ships executable code, which is why it is a separate plugin and
why the config lives at `hooks/enforcement.json` rather than the auto-discovered
`hooks/hooks.json`. See [`SECURITY.md`](../SECURITY.md).

To remove: `/plugin uninstall enforcement@prompt-pack`. The installer targets (`install.sh` /
`install.ps1`) do not install hooks — Claude Code plugins only.

### Installer (`claude-skills` target)

If you prefer the clone-and-install flow (e.g. to vendor skills into a repo so
teammates get them without adding a marketplace), use the installer:

```bash
cd ~/code/your-project
~/code/prompt-pack/install.sh --target claude-skills --profile fullstack

# Or install once for every project on the machine:
~/code/prompt-pack/install.sh --target claude-skills --profile fullstack --scope user
```

```powershell
cd ~\code\your-project
& ~\code\prompt-pack\install.ps1 -Target claude-skills -Profile fullstack

# Or install once for every project on the machine:
& ~\code\prompt-pack\install.ps1 -Target claude-skills -Profile fullstack -Scope user
```

Skills activate on description match, and you can invoke one explicitly by
typing `/<skill-name>` (e.g. `/code-review`). `meta/task-router` is filtered
out of this target — Claude Code's own skill discovery is the router.

### Legacy: subagents

The older `claude-code` target copies each skill to `.claude/agents/<name>.md`,
turning it into a subagent. Subagents run in a separate context window, which
is useful for isolation but means they don't share the main conversation.
Prefer `claude-skills` unless you specifically want the subagent model:

```bash
~/code/prompt-pack/install.sh --target claude-code --profile fullstack
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
   (admin). See [Codex skills docs](https://learn.chatgpt.com/docs/build-skills).
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
  Concise, scope-bounded descriptions trigger more reliably. Implicit selection
  is on unless a skill ships `agents/openai.yaml` with
  `policy.allow_implicit_invocation: false`; the pack ships no such file, so
  every skill is eligible.
- **List**: `/skills` shows what Codex discovered, which is the quickest
  check that the install landed in a scanned root.

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

OpenClaw reads skill directories from its workspace `skills/` folder, which is the
highest-precedence root. Each skill is a directory with `SKILL.md` plus optional supporting
files. OpenClaw also scans `<workspace>/.agents/skills/` and `~/.agents/skills/`, so a repo
installed with `--target agents` is picked up when it doubles as an OpenClaw workspace; do
not run both targets into the same workspace. The pack sets no `metadata.openclaw` gating
block, so every skill is always eligible and never hidden by a missing binary or env var.

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
  `.claude/skills/`, `.claude/agents/`, `AGENTS.md`, `skills/`, `docs/ai-rules/`)
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
