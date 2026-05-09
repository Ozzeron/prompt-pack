# prompt-pack

A curated, opinionated collection of system prompts and agent roles for AI coding assistants.
Built to be **simple to use**, **token-aware**, and **stack-agnostic**.

> One source of truth → multiple ways to consume: OpenClaw skills, Cursor rules, Claude Code subagents, plain copy-paste.

## Why another prompt repo

Most existing collections (awesome-cursorrules, awesome-claude-code-subagents, etc.) are dumps of markdown files
with no orchestration story and no usage discipline. This repo aims for three things:

1. **Curated, not exhaustive.** Each prompt earns its place. No 200 variants of "you are a senior X".
2. **Orchestrator-first.** A `task-router` decides which role to apply, so users don't have to memorise the catalog.
3. **Token-disciplined.** Every prompt has explicit scope limits and "don't read these things" rules,
   because context is money.

## Repository layout

```
prompts/
  architecture/      # backend, frontend, system-design roles
  review/            # code-review, security-review, ui-audit
  interface/         # ui-designer, design-tokens, ux-writer
  delivery/          # handoff, pr-writer, commit-writer
  meta/              # task-router, token-discipline, prompt-format
docs/
  USAGE.md           # how to consume in OpenClaw / Cursor / Claude Code
  CONTRIBUTING.md    # how to add or modify a prompt
  PROMPT-FORMAT.md   # the schema each prompt must follow
```

Each prompt is a directory:

```
prompts/<category>/<name>/
  SKILL.md           # the prompt itself, with YAML frontmatter
  EXAMPLES.md        # optional: sample triggers + expected outputs
  CHANGELOG.md       # optional: version history when prompts evolve
```

## How to use

The pack ships with an installer for each major AI tool. One command, six profiles, five
targets. Detailed guidance lives in [`docs/USAGE.md`](docs/USAGE.md).

### Quick start

#### Linux / macOS (bash)

```bash
# Clone once
git clone https://github.com/Ozzeron/prompt-pack.git ~/code/prompt-pack

# Install the minimal starter set into your project (Cursor)
cd ~/code/your-project
~/code/prompt-pack/install.sh --target cursor --profile minimal
```

If the script doesn't run with "permission denied" (e.g. you downloaded a zip
instead of cloning), make it executable first:

```bash
chmod +x ~/code/prompt-pack/install.sh
```

#### Windows (PowerShell)

```powershell
# Clone once
git clone https://github.com/Ozzeron/prompt-pack.git $HOME\code\prompt-pack

# Install the minimal starter set into your project (Cursor)
cd $HOME\code\your-project
& $HOME\code\prompt-pack\install.ps1 -Target cursor -Profile minimal
```

If you get "running scripts is disabled", run once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Targets

| Target        | What it does |
|---------------|---|
| `cursor`      | Copies skills into `.cursor/rules/` (frontmatter activates rules) |
| `claude-code` | Copies skills into `.claude/agents/` (subagents) |
| `codex`       | Builds a single `AGENTS.md` at project root (Codex CLI reads this) |
| `openclaw`    | Copies skill directories into `<project>/skills/` (OpenClaw workspace) |
| `raw`         | Strips frontmatter, writes bodies to `docs/ai-rules/` for paste into any AI tool |

### Profiles

| Profile     | Skills | Use case |
|-------------|--------|---|
| `minimal`   | 4 | Always-on baseline (engineering principles + reuse + token discipline + handoff) |
| `nextjs`    | 9 | Next.js / React frontend work |
| `backend`   | 12 | Backend APIs with relational DB |
| `supabase`  | 13 | Backend with Postgres + Supabase RLS |
| `fullstack` | 18 | Almost everything except niche audits |
| `all`       | 21 | Every skill in the pack |

### Custom selection

```bash
# PowerShell
.\install.ps1 -Target cursor -Skills meta/engineering-principles, architecture/frontend-feature

# Bash
./install.sh --target cursor --skill meta/engineering-principles --skill architecture/frontend-feature
```

### List everything

```bash
./install.sh --list                    # bash
.\install.ps1 -List                    # PowerShell
```

### Per-tool details

See [`docs/USAGE.md`](docs/USAGE.md) for tool-specific notes (always-on rules in Cursor,
path-specific instructions in Codex, ClawHub publication status, manual paste flow).

## Prompt format

Every prompt follows the schema in [`docs/PROMPT-FORMAT.md`](docs/PROMPT-FORMAT.md):

- YAML frontmatter (`name`, `description`, `category`, `triggers`, `version`)
- Short role statement (no inflated "senior architect" prose)
- Explicit scope and out-of-scope
- Token-discipline rules (what NOT to read, when to ask before reading large files)
- Output format
- Anti-patterns (what NOT to do)

## Orchestration

[`prompts/meta/task-router/SKILL.md`](prompts/meta/task-router/SKILL.md) is the entry point for orchestrator agents.
It maps user intents to specific prompts and decides when to spawn subagents.

A typical flow:

```
user request
  → main agent reads task-router
  → matches request to one or more prompts
  → invokes them directly OR spawns a subagent with the right role
  → aggregates output and replies
```

## Status

🟢 **v0.1.3** — first stable release. 21 skills, format-locked, lint-gated, tested across
four external review rounds. Use it.

Future breaking changes will go through deprecation in `## Notes` first, then a major
bump (v1.0.0) when the format itself changes.

## Contributing

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md). PRs welcome once the format stabilises.

## License

MIT. See [`LICENSE`](LICENSE).
