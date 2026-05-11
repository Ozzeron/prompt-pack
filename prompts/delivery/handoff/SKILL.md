---
name: handoff
description: Wrap up a coding task with a clear summary of what changed, how to verify, what's risky, and what was left out.
category: delivery
version: 0.1.0
triggers: ["summarise changes", "hand off", "PR description", "wrap up", "what did you change"]
applies_to: [openclaw, cursor, claude-code]
---

# Code Handoff

You just finished (or are about to finish) a coding task. This skill produces a structured
handoff so the human reviewer or the next agent can verify the work without re-reading every
file. It also surfaces risks, follow-ups, and proactive suggestions — without expanding
scope unilaterally.

## When to use

- After completing any non-trivial code change
- Before opening a PR (this output adapts to a PR description)
- When passing work to another agent or person

Skip for one-line edits or quick answers — overhead exceeds value.

## Scope

In scope:
- What changed and why
- How to verify (commands, URLs, manual checks)
- Risks and edge cases the author considered
- What was left out and why
- Suggestions the author noticed but didn't act on (with priority)

Out of scope:
- Marketing the work — be neutral, no "successfully implemented"
- Restating the entire diff line by line
- Scope expansion: suggestions stay in the suggestions section, not as silent changes

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — used implicitly: if the work violates these, the handoff must call it out under Risks or Suggestions.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — build the handoff from working memory, not by re-reading files.
- [`meta/artifact-hygiene`](../../meta/artifact-hygiene/SKILL.md) — source of the conditional Workspace hygiene block in the output template; include only when artifacts were produced.

## Token discipline (specific)

Inherit [`meta/token-discipline`](../../meta/token-discipline/SKILL.md). Additionally:

- Build the handoff from your own working memory of the task. Do not re-read every changed file.
- Quote file paths and line ranges, not file contents.
- If you can't remember a detail without re-reading — say "verify this" rather than fabricate.

## Output format

```
## Summary
<2-4 sentences: what was done and why it matters>

## Changes
- `<file>` — <one-line description>
- `<file>` — <one-line description>

## How to verify
1. <Concrete step: run X, open Y, check Z>
2. ...

## Tested
- ✅ <what was actually tested, automated or manual>
- ⚠️ <what was assumed, not verified>

## Workspace hygiene
<Include only when files, logs, generated data, debug scripts, backups, caches, or
temporary artifacts were created during the task. See `meta/artifact-hygiene`.>

- Intentional artifacts: <files kept on purpose>
- Temporary artifacts removed: <self-created temp files cleaned up>
- Left for user review: <unknown files not deleted; user decides>
- Debug logs/statements: <removed | kept intentionally as logging>
- Generated data / storage effects: <DB rows, files, caches written>
- Cleanup recommendation: <none | run command X | delete path Y after verification>

## Risks / edge cases
- <Edge case considered and how it's handled, or why it's acceptable>

## Out of scope (not done)
- <Thing the user might expect but wasn't included, with reason>

## Suggestions
> Surface only. Not applied. User decides.

- **Must:** <something that should be done soon, e.g. a follow-up bug exposed by this work>
- **Nice-to-have:** <improvement worth doing if time allows>
- **Out-of-scope idea:** <larger thing for a separate task>
```

Drop sections that are empty. If there are no risks, no out-of-scope items, or no
suggestions — omit those headings rather than writing "none". Omit Workspace hygiene
entirely when the task did not create, modify, or generate any artifacts.

## Anti-patterns

- ❌ "Successfully implemented X" — neutral tone, leave the judgement to the reviewer
- ❌ Pasting the diff into the summary
- ❌ Hiding skipped items — if you didn't do X, say so in "Out of scope"
- ❌ Slipping suggestions in as actual changes — suggestions are surfaced, not applied
- ❌ "Tests pass" without saying which tests — quote the command and the result count
- ❌ Claiming things work when you didn't run them — use "verify this" instead

## Notes

For PR descriptions, the same template works — just prepend a one-line title and append
a "Closes #N" footer if applicable.

When suggestions touch security, data integrity, or user-facing breakage, escalate them to
**Must** even if outside the original task. Better to surface than miss.
