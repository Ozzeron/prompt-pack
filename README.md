# prompt-pack

A curated, opinionated collection of system prompts and agent roles for AI coding assistants.
Built to be **simple to use**, **token-aware**, and **stack-agnostic**.

> One source of truth → multiple ways to consume: OpenClaw skills, Cursor rules, Claude Code subagents, plain copy-paste.

## Why not another prompt list?

This is **not a prompt directory**. It is a small, opinionated
discipline pack designed to reduce the technical debt AI coding agents
generate by default.

The usual collections (awesome-cursorrules, awesome-claude-code-subagents,
awesome-copilot, awesome-agent-skills, etc.) are catalogues: hundreds or
thousands of prompts, every variant of "you are a senior X", optimised
for breadth and discoverability. Pick one, paste it in, hope.

Under those prompts, agents ship the same recurring failures regardless
of model: duplicate components, fresh utilities for things that already
exist in the repo, dependencies added for problems the project already
solved, convention drift, scope creep, and "helpful" rewrites of code
that was fine. Bigger catalogues do not fix this; they multiply the
surface where it can happen.

prompt-pack picks the opposite trade-off: **fewer skills, stronger
behaviour**. 22 curated skills, lint-gated, one orchestrator, explicit
inheritance, hardened across nine external review rounds **plus four
empirical field tests** — the pack ran on real codebases and we patched
what dropped, including the encoding and Cursor-format issues a
model-only review would never have caught. It is small enough that you
can read the whole catalogue in one sitting and audit what your agent
is actually being told.

The discipline that does the work:

1. **Reuse before create.** A central `reuse-before-create` skill,
   inherited by every code-creating role, forces the agent to search
   for an existing artifact before adding a new one. Every "new" entry
   needs a one-line justification.
2. **Convention discovery first.** Architecture skills require
   inspecting 2–3 canonical examples in the target repo before writing
   code, so the result matches the project's style instead of the
   agent's default.
3. **Attention-disciplined, not token-cheap.** Every prompt has explicit
   scope limits and "don't read these things" rules, because context is
   an *attention budget* and a window stuffed with low-signal files
   makes the model worse — even at unlimited cost. Bigger context is
   not smarter context.
4. **Orchestrator-first.** A `task-router` maps user intents to specific
   roles, including composed flows (PR review = code-review →
   security-review), so users don't memorise the catalog.
5. **Curated, not exhaustive.** Each prompt earns its place.
   No 200 variants of "you are a senior X".

### What this is not

- Not a `.cursorrules` collection. The pack ships a real installer with
  six targets (Cursor, Claude Code, Codex with skills, Codex legacy AGENTS.md,
  OpenClaw, raw paste) and six profiles, plus a linter that enforces the
  format on every PR.
- Not a vendor-specific bundle. It runs on whatever AI coding tool you
  already use; no migration, no platform lock-in.
- Not a benchmark or a leaderboard. It is opinionated discipline, not
  a claim to beat anyone on a synthetic eval.
- Not exhaustive. If your stack needs a skill that is not here,
  open an issue — a small principled pack beats a huge unaudited one.

### Context discipline, not token cheapness

The pack does not try to make the agent read as little as possible. It
tries to make the agent read the **right things first**, then widen the
read only when correctness demands it.

For small tasks that means staying lean. For risky work — refactors,
database changes, security review, PR review — it means spending more
context on the files that actually reduce uncertainty, and skipping the
ones that just add noise.

The goal is not lower token usage. The goal is **better signal per
token**. Even on unlimited budget, a model that reads everything is a
model that mixes patterns from unrelated code and hallucinates with
confidence. Tokens are an attention budget; spend them where they buy
reliability.

## Repository layout

```
prompts/
  architecture/      # backend-api, frontend-feature, database-schema,
                     #  database-migrations, postgres-supabase, refactor-planner
  review/            # code-review, repo-audit, security-review,
                     #  frontend-audit, database-review,
                     #  duplication-audit, debugger
  interface/         # ui-designer
  delivery/          # handoff, test-writer, doc-writer, ai-agent-docs
  meta/              # task-router, engineering-principles, reuse-before-create,
                     #  token-discipline
docs/
  USAGE.md           # how to consume in OpenClaw / Cursor / Claude Code / Codex
  CONTRIBUTING.md    # how to add or modify a prompt (incl. reviewer checklist)
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

The pack ships with an installer for each major AI tool. One command, six profiles, six
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

| Target            | What it does |
|-------------------|---|
| `cursor`          | Copies skills into `.cursor/rules/` (frontmatter activates rules) |
| `claude-code`     | Copies skills into `.claude/agents/` (subagents) |
| `codex`           | Codex-native: each skill goes to `.agents/skills/<name>/SKILL.md`, plus a compact `AGENTS.md` router/bridge. Use `--scope user` to install to `$HOME/.agents/skills/` instead. |
| `codex-agents-md` | Legacy single-file install. Concatenates skills into one `AGENTS.md` (capped at 32 KiB). Use only if your host doesn't support `.agents/skills/`. |
| `openclaw`        | Copies skill directories into `<project>/skills/` (OpenClaw workspace) |
| `raw`             | Strips frontmatter, writes bodies to `docs/ai-rules/` for paste into any AI tool |

### Profiles

| Profile     | Skills | Use case |
|-------------|--------|---|
| `minimal`   | 4 | Core baseline pulled in via `## Inherits` by other skills (engineering principles + reuse + token discipline) plus `delivery/handoff` for end-of-task summaries |
| `nextjs`    | 10 | Next.js / React frontend work |
| `backend`   | 13 | Backend APIs with relational DB |
| `supabase`  | 14 | Backend with Postgres + Supabase RLS |
| `fullstack` | 21 | Almost everything (includes frontend / duplication audits) |
| `all`       | 23 | Every skill in the pack |

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

[`prompts/meta/task-router/SKILL.md`](prompts/meta/task-router/SKILL.md) is the entry
point for orchestrator agents. It maps user intents to specific prompts and decides
when to spawn subagents.

A typical flow:

```
user request
  → main agent reads task-router
  → matches request to one or more prompts
  → invokes them directly OR spawns a subagent with the right role
  → aggregates output and replies
```

For multi-pass intents the router exposes **composed flows** instead of single skills:

| Intent | Sequence |
|---|---|
| Full PR review | `review/code-review` → `review/security-review` |
| Schema change PR | `review/database-review` → `review/code-review` → `review/security-review` |
| Refactor execution | `architecture/refactor-planner` → `review/duplication-audit` (optional) → implementation |

## Status

🟢 **v0.2.0** — current stable release. Adds Codex-native skills target
(`--target codex` writes to `.agents/skills/<name>/SKILL.md` with progressive
disclosure, plus a compact router-bridge `AGENTS.md`); the previous monolithic
AGENTS.md installer is preserved as `--target codex-agents-md` for hosts that
don't yet support `.agents/skills/`. 22 skills, format-locked, lint-gated.
Use it.

Future breaking changes will go through deprecation in `## Notes` first, then a major
bump (v1.0.0) when the format itself changes.

## Contributing

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md). The format is stable for the v0.1.x line
(schema in [`docs/PROMPT-FORMAT.md`](docs/PROMPT-FORMAT.md), enforced by `npm run lint`); the
reviewer checklist in CONTRIBUTING is the gate for every PR. New skills, fixes, and content
contributions are welcome — open an issue first for new skills.

## License

MIT. See [`LICENSE`](LICENSE).
