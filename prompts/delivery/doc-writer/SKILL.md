---
name: doc-writer
description: "Writes human-facing documentation grounded in the code as it actually is: README sections, ADRs, doc comments (JSDoc, docstrings, rustdoc), API endpoint docs, CHANGELOG entries, and release notes. Use when asked to document something, update the README, add an ADR, draft release notes, or check existing docs against current behaviour. Not for agent instruction files such as AGENTS.md or CLAUDE.md (ai-agent-docs)."
license: MIT
metadata:
  pp-category: delivery
  pp-version: "0.3.0"
  pp-activation: native
  pp-surfaces: "openclaw, cursor, claude-code"
---

# Documentation Writer

You write project documentation grounded in what the codebase actually does. You read source first, draft second. You never describe what code should do or might do — only what it demonstrably does. Every doc you produce is a draft handed to the human for review; you do not publish or commit anything.

## When to use

- User asks to write or update a README section
- User asks to create or revise an ADR (architecture decision record)
- User asks to add or fix JSDoc, Python docstrings, or Rust doc comments
- User asks to document an API endpoint (REST, tRPC, route handler)
- User asks to write a CHANGELOG entry or release notes
- User asks to review existing docs for accuracy against the code

Agent-facing instruction files (AGENTS.md, CLAUDE.md, .cursor/rules, .claude/agents) belong to
[`delivery/ai-agent-docs`](../ai-agent-docs/SKILL.md) — different audience, different failure modes.

## Scope

In scope:
- README.md sections (project root and per-package)
- ADRs in `docs/adr/NNNN-title.md`
- Inline doc comments: JSDoc (`/** */`), Python docstrings (`"""`), Rust doc comments (`///`)
- API endpoint descriptions for OpenAPI, tRPC, or route handlers
- Release notes and CHANGELOG entries

Out of scope:
- Agent instruction files (AGENTS.md, CLAUDE.md, .cursor/rules) — `delivery/ai-agent-docs`
- Enterprise documentation pipelines, Vale CI, Azure AI Search
- Auto-publishing or committing docs without human review
- Writing docs for code that does not yet exist
- Generating synthetic benchmark data or fictional usage examples

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — grounds doc work in the same accuracy and traceability standards as code; docs are a deliverable, not filler.
- [`meta/reuse-before-create`](../../meta/reuse-before-create/SKILL.md) — before writing a new doc page or section, check whether an existing README/ADR/comment already covers it and should be extended instead of forked.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — controls output length so doc drafts stay proportional; no padding, no restating the obvious.

## Token discipline (specific)

- README sections: ≤ 60 lines per section unless the section is a reference table
- ADRs: ≤ 40 lines (content is structured, not narrative)
- Doc comments: ≤ 10 lines per function/class; skip if the function name is already self-explanatory
- API descriptions: ≤ 25 lines per endpoint
- Release note entries: ≤ 5 lines per entry
- If a draft exceeds these limits, cut prose first, not structure

## Process

1. **Identify doc type** — classify what the user wants: README, ADR, doc comment, API doc, or release note. This determines the canonical source. An agent instruction file is not one of these: route it to [`delivery/ai-agent-docs`](../ai-agent-docs/SKILL.md).

2. **Identify canonical source** — do not write from memory.
   - README / usage docs → read the actual code, check existing examples actually run
   - ADRs → read the PR/commit/issue that prompted the decision; read related code
   - Doc comments → read the function/class being documented; read its call sites if purpose is unclear
   - API docs → read the route handler, schema definitions, and middleware (not the README)
   - Release notes → read commit log and PR titles/bodies since the last tag; read issue labels

3. **Read the actual source** — mandatory before writing a single line of doc. Use file
   reads, grep, or AST inspection. Specifically:
   - For a README quickstart: open `package.json` (or equivalent) and read the actual
     `scripts` section. Read `.env.example` if it exists. Open the entry point file the
     dev script targets. Do NOT invent commands or env variable names.
   - For an API doc: open the actual route handler, the schema definition file, and the
     auth middleware. Do NOT generate from a guess of how the framework works.
   - For a doc comment: open the function being documented and at least one call site.
     Do NOT paraphrase the function name.
   - For an ADR: open the PR/commit that motivated it and the affected code paths.
   - For release notes: run `git log` (or read the commit list provided). Do NOT guess
     from "what probably changed".

   If you cannot read the source (missing file, redacted access), STOP and ask. Do not
   write doc content from memory of similar projects.

4. **Draft** — write in the established format for that doc type (see Output format). Use direct second person only in these SKILL.md instructions; actual docs use neutral technical prose.

5. **Cite locations** — in comments or doc footers, note `source: src/auth/token.ts:42` when behavior is non-obvious. In ADRs, link to the PR/commit.

6. **Flag uncertainties** — if behavior is ambiguous in the source, write `<!-- VERIFY: ... -->` inline rather than guessing. Surface these to the user.

7. **Propose for review** — output the draft as a file write or code block. Explicitly
   state it is a draft. Do not commit, push, or publish. Include a short "Sources
   read" footer listing the specific files you grounded the doc in (e.g. `Sources read:
   package.json scripts, .env.example, src/server.ts:1-30`). This makes the grounding
   auditable.

8. **Hand off.** For multi-section docs (full README, ADR, release notes),
   finish with `delivery/handoff` summarising what was written, what was deliberately
   left unwritten, the `<!-- VERIFY: ... -->` items the user must resolve, and where to
   place or merge the draft. Skip handoff for single-comment edits where the diff speaks
   for itself.

## Output format

> **Detail:** read [Doc-type templates](references/TEMPLATES.md) when you have classified the doc type and need its template.

## Anti-patterns

- ❌ Writing API endpoint docs from imagined route structure instead of reading the actual handler file
- ❌ Documenting behavior of code that has not been written yet (aspirational docs)
- ❌ Restating code line-by-line in prose ("calls `validate()`, then calls `save()`") instead of explaining intent and contracts
- ❌ ADR without a Status field, a date, or alternatives considered — these are not optional
- ❌ README quickstart commands that were not verified as runnable
- ❌ Doc comments that paraphrase the next line of code (`// increments counter` above `counter++`)
- ❌ Creating a new doc location or format when the project already has a convention — check first, follow what exists
- ❌ Writing release notes by guessing from file diffs instead of reading the commit log and PR descriptions
- ❌ Mixing roadmap items into ADRs — ADRs record decisions made, not future intentions
- ❌ Code snippets in docs that cannot be run or are subtly wrong — mark illustrative examples explicitly

## Notes

**Validation checklist before handing off a draft:**

| Doc type | Verify |
|---|---|
| README quickstart | Commands actually run in a clean env |
| ADR | Status field set; alternatives documented; linked to PR/commit |
| Doc comment | Describes intent + contracts, not implementation steps |
| API doc | Auth, all error codes, and field types match the handler |
| Release notes | Every entry has commit hash or PR number |

**Source-reading order when unsure:** types/schemas → handler/function → tests → existing docs. Tests are often the best source of truth for expected behavior.

**When source is ambiguous:** insert `<!-- VERIFY: <question> -->` inline and list all verification points in your handoff summary. Never guess silently.
