# Usage

How to actually consume `prompt-pack` in different AI tools. There is no single one-liner
installer (yet) — pick the path that fits your workflow.

## Cursor

Each `SKILL.md` is compatible with Cursor's `.cursor/rules/` directory.

```bash
# Once: clone or fork the pack somewhere
git clone https://github.com/Ozzeron/prompt-pack.git ~/code/prompt-pack

# In your project: link the skills you want
mkdir -p .cursor/rules
cp ~/code/prompt-pack/prompts/meta/engineering-principles/SKILL.md \
   .cursor/rules/engineering-principles.md
cp ~/code/prompt-pack/prompts/meta/token-discipline/SKILL.md \
   .cursor/rules/token-discipline.md
cp ~/code/prompt-pack/prompts/architecture/frontend-feature/SKILL.md \
   .cursor/rules/frontend-feature.md
```

Cursor reads the frontmatter `description` and matches based on context. Restart Cursor
or reload the window after copying.

For project-wide always-on rules (engineering-principles, token-discipline), prefer
`.cursorrules` in repo root or `globs: '**/*'` frontmatter so the rules apply broadly.

## Claude Code

Copy any `SKILL.md` into `.claude/agents/<name>.md`:

```bash
mkdir -p .claude/agents
cp ~/code/prompt-pack/prompts/architecture/backend-api/SKILL.md \
   .claude/agents/backend-api.md
```

Claude Code picks up files in `.claude/agents/` automatically as subagents. The
`description` in frontmatter is what Claude Code displays when matching.

## OpenClaw / ClawHub

When a skill is published to the ClawHub registry (see CHANGELOG of each skill for
status), install by slug:

```bash
clawhub install <skill-slug>
clawhub list
```

ClawHub installs into `<workdir>/skills/<slug>/`. Skills are picked up automatically by
the OpenClaw main agent.

For manual install (no ClawHub publication yet), copy the directory into your OpenClaw
workspace skills folder:

```bash
cp -r ~/code/prompt-pack/prompts/meta/engineering-principles \
      ~/.openclaw/workspace/skills/engineering-principles
```

## ChatGPT / Claude / any AI tool

Open the `SKILL.md` you want, copy the body (everything after the closing `---` of the
frontmatter), and paste it into:

- ChatGPT: a custom GPT's Instructions, or a system prompt at the top of the conversation
- Claude.ai: the project's Custom Instructions
- Any other tool: its system-prompt or persistent-instruction field

The frontmatter is metadata; the AI doesn't need to see it.

## Recommended starter set

If you don't know where to begin, install these three first. They give you the most
benefit per skill:

1. **`meta/engineering-principles`** — DRY, file size, type safety, modern standards.
   Always-on baseline.
2. **`meta/token-discipline`** — what to read and what not to. Saves money on every
   request.
3. **`delivery/handoff`** — structured wrap-up after any task. Catches the "task
   complete? what did you do?" hole.

After that, add skills relevant to what you're doing this week:

- Frontend work: `interface/ui-designer` + `architecture/frontend-feature`
- Backend work: `architecture/backend-api`
- Database work: `architecture/database-schema` + `architecture/database-migrations`
   (+ `architecture/postgres-supabase` for Supabase)
- Reviewing PRs: `review/code-review`
- Auditing legacy frontend: `review/frontend-audit`
- Reviewing DB / queries: `review/database-review`

## Orchestration pattern

If you operate a "main agent" that delegates to specialists (Claude Code, OpenClaw, custom
agent runtime), install **`meta/task-router`** alongside the specialist skills. The router
maps user intents to the right specialist and decides when to spawn a subagent.

```
user request
  → main agent reads task-router
  → matches request to one or more skills
  → invokes inline OR spawns a subagent with the right role
  → aggregates output and replies
```

## Updating

When you pull updates from the pack, re-copy any skills you've installed. There's no
auto-sync yet.

```bash
cd ~/code/prompt-pack && git pull
# Then re-copy whatever you've linked
```

If you've modified a skill locally for your project, keep the modification in your
project, not in the upstream pack — the pack stays generic.
