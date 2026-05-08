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

This pack is the source of truth on GitHub. There is no single one-liner installer (yet) —
ClawHub publishes one skill per slug, not whole repositories. Pick the path that fits your
workflow.

### 1. OpenClaw / ClawHub (per-skill)

Once a skill is published to the ClawHub registry, install it by slug:

```bash
clawhub install <skill-slug>
```

Publication status of each skill is tracked in its `CHANGELOG.md`. Until a skill is marked
published, install it manually (see method 4).

### 2. Cursor

Copy any `SKILL.md` into `.cursor/rules/<name>.md` in your project. The frontmatter is
Cursor-compatible. The rule activates based on its `description` and `triggers`.

### 3. Claude Code

Copy any `SKILL.md` into `.claude/agents/<name>.md`. Claude Code will pick it up as a
subagent.

### 4. Manual / any AI tool

```bash
git clone https://github.com/Ozzeron/prompt-pack.git
```

Then copy the body of any `SKILL.md` you want to use into your AI tool's system prompt or
custom-instructions field. The frontmatter is metadata only; the prompt itself starts at
the first heading.

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

🚧 Early stage. The repository is being seeded with a small set of high-quality prompts.
Expect breaking changes to format until v0.1.0.

## Contributing

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md). PRs welcome once the format stabilises.

## License

MIT. See [`LICENSE`](LICENSE).
