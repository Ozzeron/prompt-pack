# prompt-pack

A curated, opinionated **Agent Skills library** for AI coding assistants.
Built to be **simple to use**, **token-aware**, and **stack-agnostic**.

> Built on the [Agent Skills](https://agentskills.io/specification) open standard:
> spec-conformant `SKILL.md` frontmatter, progressive disclosure via `references/`,
> descriptions written for activation. Installs as a Claude Code plugin, as
> `.agents/skills/` for Cursor / Codex / Copilot / OpenClaw, or through the installer for
> older layouts.

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
behaviour**. 23 curated skills, lint-gated, native skill discovery
(with `task-router` for legacy/orchestrated flows), explicit
inheritance, hardened across nine external review rounds **plus four
empirical field tests** — the pack ran on real codebases and we patched
what dropped, including the encoding and Cursor-format issues a
model-only review would never have caught. It is small enough that you
can read the whole catalogue in one sitting and audit what your agent
is actually being told.

What backs that up, and what does not: `npm run lint` enforces the format and spec
contract, `npm run eval:descriptions` scores 58/58 labelled queries onto the right skill,
`npm run test:hooks` covers 24 enforcement cases, and CI does real installs on Linux,
macOS, and Windows (PowerShell 5.1 included) with byte-for-byte parity between the two
installers, the Codex AGENTS.md bridge and policy files included. Behavioural quality — does a skill actually catch the planted N+1, the missing
authz check, the duplicate util — is exercised against `evals/fixtures/shop/` by hand, not
in CI, so this README publishes no pass rate for it.

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
4. **Orchestrator-aware.** For legacy rules, OpenClaw, and Claude Code
   subagent flows, `task-router` maps user intents to specific roles,
   including composed flows (PR review = code-review → security-review).
   For native Agent Skills targets (`cursor`, `agents`), host skill
   discovery is the router — descriptions are the primary activation surface.
5. **Curated, not exhaustive.** Each prompt earns its place.
   No 200 variants of "you are a senior X".
6. **Enforced where prose is not enough.** Three of the pack's own rules ship as
   deterministic `PreToolUse` hooks in the opt-in `enforcement` plugin: no reads of
   dependency trees or build output, no new source file that duplicates an existing name,
   no dependency installed without clearing the bar. A skill can ask; a hook cannot be
   reasoned around.
7. **Measured where it can be measured.** The description is the whole activation surface,
   so it is the one part that is testable offline: `evals/descriptions/cases.yaml` labels
   59 real-user phrasings with the skill that must win, near misses included.

### What this is not

- Not a `.cursorrules` collection. The pack ships a real installer with
  ten targets (Cursor 2.4+ Skills, Cursor foundation-only, Cursor legacy
  rules, universal `.agents/skills/`, Claude Code Skills, Claude Code
  subagents, Codex skills, Codex legacy AGENTS.md, OpenClaw, raw paste) and
  six profiles, plus a linter that enforces the format on every PR.
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
  infra/             # docker
  meta/              # task-router, engineering-principles, reuse-before-create,
                     #  token-discipline
hooks/
  enforcement.json   # opt-in PreToolUse config (NOT hooks/hooks.json: opt-in by design)
  scripts/           # three guards, fail-open, no network, no writes
evals/
  descriptions/      # labelled activation queries (gates CI)
  fixtures/shop/     # small repo with planted defects + DEFECTS.yaml answer key
docs/
  USAGE.md           # how to consume in OpenClaw / Cursor / Claude Code / Codex
  CONTRIBUTING.md    # how to add or modify a prompt (incl. reviewer checklist)
  PROMPT-FORMAT.md   # the schema each prompt must follow
AGENTS.md            # this repo's own agent instructions (CLAUDE.md imports it)
SECURITY.md          # what installing actually puts on your machine
```

Each prompt is a directory:

```
prompts/<category>/<name>/
  SKILL.md           # the always-loaded core, 80-240 lines, spec frontmatter
  references/        # optional: loaded on demand, each linked with a "read X when Y"
    EXAMPLES.md      #   worked examples
    TEMPLATES.md     #   output templates, per-branch checklists, coverage passes
```

## How to use

The pack ships with an installer for each major AI tool. One command, six profiles, ten
targets. Claude Code users can skip the installer entirely and use the plugin
marketplace. Detailed guidance lives in [`docs/USAGE.md`](docs/USAGE.md).

### Quick start

#### Claude Code (plugin — no clone needed)

The repo is a Claude Code plugin marketplace. Add it once, then install one
profile plugin (they overlap by design — pick ONE):

```
/plugin marketplace add Ozzeron/prompt-pack
/plugin install fullstack@prompt-pack
```

Available plugins mirror the installer profiles: `minimal`, `nextjs`, `backend`,
`supabase`, `fullstack`, `all-skills`. Skills activate on description match;
`meta/task-router` is excluded — Claude Code's own skill discovery is the router.
Updates ship with `/plugin update`, no re-clone or re-run needed.

Optionally layer the enforcement hooks on top of any profile:

```
/plugin install enforcement@prompt-pack
```

That one installs no skills — only the three `PreToolUse` guards described in
[`SECURITY.md`](SECURITY.md). Everything else in the pack is Markdown and nothing else.

#### Cursor / Codex / Copilot / OpenClaw (`npx skills` — no clone needed)

The repo is a valid [skills.sh](https://skills.sh) source. One command writes the skills to
`.agents/skills/`, the root all four hosts read, and pins what it installed in
`skills-lock.json`:

```bash
npx skills add Ozzeron/prompt-pack
```

Pick skills in the prompt, or take everything with `--all`. Two differences from the
installer's `agents` target: `npx skills` also ships `meta/task-router` (drop it with
`npx skills remove task-router`; native hosts route by description), and it copies files
verbatim, so the cross-skill links inside a `SKILL.md` keep their repo-relative paths and
do not resolve in the flat layout. Treat them as names, not paths. Update with
`npx skills update`.

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

Two of these carry the pack forward: **`claude-skills`** (or the plugin above) and
**`agents`** for everything else. The rest exist for hosts that predate Agent Skills;
they are maintained but not developed, and the flat ones (`cursor-rules`,
`codex-agents-md`, `claude-code`, `raw`) cannot carry `references/` files, so skills
installed that way lose their on-demand material.

| Target            | What it does |
|-------------------|---|
| `cursor`          | Cursor 2.4+ Skills-native. Foundation rules go to `.cursor/rules/*.mdc` (alwaysApply); every other skill becomes a Cursor Agent Skill at `.cursor/skills/<name>/SKILL.md`. |
| `cursor-foundation` | Foundation-only Cursor install. Writes only the three always-on rules to `.cursor/rules/*.mdc`; no `.cursor/skills/`. Pair with `agents` to avoid duplicate skill roots in Cursor. |
| `cursor-rules`    | Legacy Cursor target. Every skill in `.cursor/rules/*.mdc` plus a `prompt-pack-router.mdc` bridge. Use only for Cursor builds older than 2.4. |
| `agents`          | Universal Agent Skills. Writes every skill to `.agents/skills/<name>/SKILL.md` — works in Cursor 2.4+, Codex CLI, GitHub Copilot, and OpenClaw from one install. No AGENTS.md. |
| `claude-skills`   | Claude Code native Agent Skills. Each skill goes to `.claude/skills/<name>/SKILL.md`. Use `--scope user` to install to `$HOME/.claude/skills/` instead. |
| `claude-code`     | Legacy Claude Code subagents: copies skills into `.claude/agents/`. Prefer `claude-skills` on current builds. |
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
| `enforcement` | — | Not a skill profile: the three PreToolUse guards. Layer on any of the above (Claude Code plugin only) |

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

- Spec-conformant YAML frontmatter: `name`, `description`, `license`, and pack fields
  under `metadata` (`pp-category`, `pp-version`, `pp-activation`) — no invented top-level keys
- A description written for activation: what it does + `Use when …` + `Not for …`,
  120-500 chars, with the literal words users type
- Progressive disclosure: conditional material in `references/`, linked with a load condition
- Short role statement (no inflated "senior architect" prose)
- Explicit scope and out-of-scope
- Token-discipline rules (what NOT to read, when to ask before reading large files)
- Output format
- Anti-patterns (what NOT to do)

## Orchestration (legacy hosts only)

On a native Agent Skills host — Claude Code, Cursor 2.4+, Codex — routing is not the pack's
job. The host matches the request against skill descriptions, which is why descriptions
carry `Use when …` and `Not for …` clauses and why the activation eval exists. Adding a
router skill on top of that gives you a second, worse matcher.

[`prompts/meta/task-router/SKILL.md`](prompts/meta/task-router/SKILL.md) is therefore marked
`pp-activation: legacy` and excluded from every native target. It stays in the pack for
pre-Agent-Skills setups: plain rules files, OpenClaw, Claude Code subagent flows, and the
Codex `AGENTS.md` bridge, where nothing else can do the mapping.

A typical flow (legacy / rules mode):

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

🟢 **v0.5.0** — the spec-conformance release. Everything below is enforced by CI, not
asserted:

- **Frontmatter matches the Agent Skills spec.** `category`, `version`, `triggers`, and
  `applies_to` were invented top-level keys; they now live under `metadata` as `pp-*`
  strings. `triggers` is gone — its phrases moved into the description, which is what hosts
  actually match on.
- **Descriptions are written for activation**, 384-452 chars each (was a 120-char cap, which
  cannot hold what + when + when-not). The activation eval scores 58/58 offline and 59/59
  through the real matcher (`--llm`, run by hand before release) against a 95% floor;
  the first run scored 84.7% and every miss was a real missing keyword.
- **Progressive disclosure.** Nine skills moved templates, coverage passes, and worked
  examples into `references/`, each linked with an explicit load condition. Core `SKILL.md`
  budget: 240 lines, down from 310.
- **Enforcement hooks** (`enforcement@prompt-pack`, opt-in): 3 `PreToolUse` guards, 24
  tested cases, fail-open, Linux + Windows in CI.
- **Behavioural fixture** with 7 planted defects and an answer key, run by hand.

Still **23 skills**, format-locked, lint-gated. `meta/task-router` is now explicitly
`legacy`. (v0.4.1 brought Codex profile-aware links; v0.3.0 brought `infra/docker`.)

Use it.

Future breaking changes will go through deprecation in `## Notes` first, then a major
bump (v1.0.0) when the format itself changes.

## Contributing

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md). The format is stable for the v0.x line
(schema in [`docs/PROMPT-FORMAT.md`](docs/PROMPT-FORMAT.md), enforced by `npm run lint`); the
reviewer checklist in CONTRIBUTING is the gate for every PR. New skills, fixes, and content
contributions are welcome — open an issue first for new skills.

## License

MIT. See [`LICENSE`](LICENSE).
