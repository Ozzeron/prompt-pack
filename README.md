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

### 1. OpenClaw / ClawHub

```bash
clawhub install ozzeron/prompt-pack
```

Skills become available immediately to your main agent and any spawned subagents.

### 2. Cursor

Copy any `SKILL.md` into `.cursor/rules/<name>.md` in your project. The frontmatter is Cursor-compatible.

### 3. Claude Code

Copy any `SKILL.md` into `.claude/agents/<name>.md`. Claude Code will pick it up as a subagent.

### 4. ChatGPT / plain text

Open the `SKILL.md`, copy the body, paste into your conversation. The role and rules apply for the session.

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
