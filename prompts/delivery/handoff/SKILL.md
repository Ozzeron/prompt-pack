---
name: handoff
description: "Closes out a coding task with a structured handoff: what changed and why, how to verify it, risks and known gaps, what was deliberately left out, and follow-ups. Use when the work is finished and the user asks to wrap up, summarise the changes, or draft a PR description, or when passing work to another agent or person. Not for one-line edits or quick answers, where the overhead beats the value."
license: MIT
metadata:
  pp-category: delivery
  pp-version: "0.2.0"
  pp-activation: native
  pp-surfaces: "openclaw, cursor, claude-code"
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
suggestions — omit those headings rather than writing "none".

> **Detail:** read [worked handoffs](references/EXAMPLES.md) when you are unsure how much detail a handoff of this size warrants.

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
