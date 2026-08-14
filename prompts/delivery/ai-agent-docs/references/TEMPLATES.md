# Agent-file templates

> Reference for [ai-agent-docs](../SKILL.md). Load it when you know which file you are writing (AGENTS.md, CLAUDE.md, .cursor/rules, .claude/agents, copilot-instructions) and need its skeleton.

### AGENTS.md template

```markdown
# <Project Name>

<One sentence: what this repo does.>

## Stack

<Language> · <Framework> · <DB/ORM> · <Key lib 1> · <Key lib 2>

## Triggers

Explicit conditions that activate specific workflows. Each trigger names what to look
for and what to do.

- **When the user asks to add an API endpoint** → follow `src/routes/` patterns;
  validate inputs with Zod; add a test in `tests/api/`
- **When you see a `.sql` file under `migrations/`** → read the most recent 3 migrations
  before adding a new one; preserve naming convention `NNNN_<verb>_<subject>.sql`
- **When the user asks to debug a failing test** → run the failing test in isolation first;
  do not fix unrelated tests in the same change
- **When you see `// TODO: agent`** in code → that section is awaiting agent work;
  read the surrounding context before acting

## Commands

```bash
npm test          # run all tests
npm run lint      # ESLint + type check
npm run build     # production build
npm run dev       # local dev server (port 3000)
```

## Conventions

- TypeScript strict mode — no `any`, no `// @ts-ignore`
- Zod for all schema validation at API boundaries
- shadcn/ui for UI components — do not add new component libraries
- Error handling: throw typed errors (`AppError`), never return error tuples
- Database: Drizzle ORM — raw SQL only in `db/queries/raw/`
- File naming: `kebab-case` for files, `PascalCase` for components
- Imports: always use `@/` path alias, never relative `../../`

## Forbidden zones

- `dist/` — generated, do not edit
- `node_modules/` — do not touch
- `src/generated/` — auto-generated from OpenAPI spec, edit the spec instead
- `legacy/` — frozen code, no changes without explicit request
```

---

### CLAUDE.md template

```markdown
# CLAUDE.md

@AGENTS.md

<!-- Claude Code reads CLAUDE.md preferentially. Use @AGENTS.md to inherit shared
     context, then add Claude-Code-specific overrides below. -->

## Claude Code specifics

- Use `TodoWrite` and `TodoRead` tools to track multi-step tasks
- Prefer `Bash` over multiple `Read` calls for large directory trees
- When in doubt about a convention, check `AGENTS.md` before asking
```

If not inheriting from AGENTS.md, write CLAUDE.md as a full standalone with the AGENTS.md template structure.

---

### .cursor/rules/\<name\>.md template

```markdown
---
description: <One line — what this rule does and when it activates>
globs: ["src/api/**/*.ts", "src/schemas/**/*.ts"]
alwaysApply: false
---

# <Rule name>

## When this activates

This rule applies when editing files matching `src/api/**` or `src/schemas/**`.

## Conventions

- All API handlers must import from `@/schemas/<resource>`
- Return type must be explicitly typed, no implicit `any`
- Validate request body with `schema.parse(req.body)` — never trust raw input

## Commands

```bash
npm run lint:api   # lint API layer only
```

## Do not

- Add raw `req.body` access without Zod parse
- Import directly from `../../db` — use `@/db`
```

Frontmatter: `alwaysApply: true` = global injection (use sparingly); `globs: [...]` = path-scoped (preferred); `description:` = Cursor relevance fallback when neither fires.

---

### .claude/agents/\<name\>.md template

```markdown
---
description: <One line, specific trigger. "Runs database migrations and seeds dev data" not "Database helper".>
---

## Role
<One sentence. What this subagent does.>

## Commands
```bash
npx drizzle-kit generate   # generate migration
npm run db:seed            # seed dev database
npm run db:reset           # drop + re-migrate + seed (dev only — confirm first)
```

## Scope
In scope: generating/applying migrations, seeding dev/test databases.
Out of scope: schema design decisions, production database access.

## Forbidden
- Do not run `db:reset` without explicit user confirmation
- Do not touch `src/generated/` — that's the OpenAPI layer
```

---

### GitHub Copilot (.github/copilot-instructions.md)

Same structure as AGENTS.md template. Keep it tighter — Copilot is in-editor with a narrower context budget.

---

### Path-specific instructions (monorepo)

For a monorepo: root `AGENTS.md` covers layout + shared commands; each workspace (`apps/web/`, `apps/api/`) has its own `AGENTS.md` for package-specific conventions only. Child files add only what's different. For Cursor, prefer `.cursor/rules/` with `globs:` over nested AGENTS.md files.
