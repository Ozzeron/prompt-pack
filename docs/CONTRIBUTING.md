# Contributing

Thanks for considering a contribution. The pack is intentionally curated, so not every
prompt fits — but good additions and improvements are welcome.

## What belongs here

A new skill earns its place when:

1. **It addresses a recurring AI failure mode.** "AI agents tend to do X wrong" is the
   strongest motivation. Vague "best practices" prompts are not.
2. **It's not already covered.** Search the catalog. If 80% overlaps an existing skill,
   improve that one instead of adding a new one.
3. **It has clear scope and out-of-scope.** A skill that "helps with frontend things" is
   too broad. A skill that "builds a frontend feature end-to-end" is right-sized.
4. **It produces actionable output.** Skills that output buzzwords without specific
   recommendations don't ship.

What does NOT belong:

- "You are a senior X" persona prompts without operational guidance
- Personal preferences without justification ("always use Tailwind")
- Anything tied to a specific company, product, or non-public service
- Single-use prompts ("write a haiku about React")

## Format

Every skill follows the schema in [`docs/PROMPT-FORMAT.md`](PROMPT-FORMAT.md). Required:

- YAML frontmatter (`name`, `description`, `category`, `version`)
- One-paragraph role statement
- "When to use" with concrete triggers
- Scope (in / out)
- Token discipline (specific to the skill)
- Process (numbered steps)
- Output format
- Anti-patterns (the AI failure modes this skill prevents)

Skills should typically fit in 80–250 lines. Larger skills split into smaller ones or
move detail into supporting files in the same directory (`EXAMPLES.md`, `CHANGELOG.md`).

## Inheritance

Coding skills must declare what they inherit:

```markdown
## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — DRY, file size, type safety
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — what to read and not to
```

Don't restate inherited rules; reference them. Skills that conflict with the meta layer
should justify the conflict, not silently override.

## Process

1. **Open an issue first** for any new skill or significant change to an existing one.
   Drive-by PRs that add a new skill without discussion will likely be declined — not
   because the skill is bad, but because the catalog needs to stay coherent.
2. **Branch from `main`**, name it `skill/<category>-<name>` for new skills or
   `fix/<area>-<short-desc>` for fixes.
3. **One skill per PR.** Touching multiple skills in one PR is OK only when they share a
   meta-layer change.
4. **Run a self-review** against the rubric in `docs/PROMPT-FORMAT.md` before opening the PR.

## Linter

Run the linter locally before opening a PR:

```bash
npm run lint
```

It checks every skill against the format contract: required frontmatter fields,
description length, required sections in order, internal link integrity, length bounds,
and project-specific leakage. If `npm run lint` is green, your skill is structurally
valid; the reviewer can focus on content.

The linter is a single file with no dependencies (`scripts/lint-skills.mjs`), works on
any Node 18+.

## PR checklist

Before opening a PR:

- [ ] `npm run lint` passes
- [ ] Frontmatter has all required fields (name, description, category, version)
- [ ] `name` matches the directory name (kebab-case)
- [ ] `description` is one line, ≤120 chars
- [ ] `version` follows semver, starts at `0.1.0`
- [ ] "When to use" lists concrete triggers, "Out of scope" lists what NOT to invoke for
- [ ] "Token discipline (specific)" is present (or inherits-only with a one-line note)
- [ ] "Anti-patterns" section has at least 5 items
- [ ] If the skill produces code recommendations, examples use idiomatic, modern syntax
- [ ] No company-specific or product-specific references unless universally applicable
- [ ] If you added a routing entry, it's in `meta/task-router/SKILL.md`

## Versioning

Bump the `version` in frontmatter when a skill's behaviour changes:

- **Patch** (`0.1.0` → `0.1.1`): typo fixes, clarification, examples
- **Minor** (`0.1.0` → `0.2.0`): new section, new rule, new anti-pattern
- **Major** (`0.1.0` → `1.0.0`): breaking change in scope, output format, or inherits

When a skill reaches v1.0.0 it's considered stable and breaking changes become a higher
bar. Until then, expect format churn.

## Style

- Prose: direct, second person ("You build...", "You audit...")
- No "I'm an AI" / "as a language model" hedging
- No motivational filler ("Great question!", "I'd be happy to...")
- Use real words, not buzzwords. "Maintainability" beats "world-class engineering excellence"
- Examples are concrete — file paths, code snippets, tool commands
- Markdown: use `##` headings, fenced code blocks with language tags, tables for lookup data

## Discussion

Open an issue or start a discussion before significant changes. The catalog is small on
purpose; coordination keeps it that way.

## License

By contributing you agree your contribution is licensed under MIT, the same as the pack.
