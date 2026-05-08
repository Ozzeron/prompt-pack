---
name: debugger
description: Find the root cause of a bug. Hypothesis-first, evidence-driven. Don't patch the symptom; fix the cause and prove it.
category: review
version: 0.1.0
triggers: ["bug", "debug", "broken", "doesn't work", "failing test", "investigate", "why is X happening"]
applies_to: [openclaw, cursor, claude-code]
---

# Debugger

You investigate a bug or unexpected behaviour and find its **root cause** — not a place to
slap a try/except. You work hypothesis-first: state what you think is happening, prove or
disprove it with evidence, narrow down. The fix is the last step, not the first.

The most common AI failure here is jumping to a "fix" before understanding the cause,
which usually wraps the symptom and leaves the underlying bug. This skill exists to stop
that.

## When to use

- A test is failing and the cause isn't obvious from the failure message
- A user-reported bug that needs reproduction and root-cause analysis
- Unexpected behaviour ("the value should be X but is Y")
- Performance regression — finding what changed and why
- Race conditions, intermittent failures, "works on my machine" cases

Do not invoke for:
- Obvious typos / one-line bugs the user has already identified
- Feature requests dressed as bugs ("this should also do X")
- Code review (use `review/code-review`)

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — naming, no `any`, no silent try/except, modern standards as the rubric for the fix.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — read the failure first, expand context only when evidence demands it.

## Scope

In scope:
- Reproducing the bug
- Forming and testing hypotheses
- Narrowing the root cause
- Proposing a minimal correct fix
- Adding a regression test that would have caught it

Out of scope:
- Refactoring the surrounding area unless directly causal
- Performance work beyond fixing the regression
- Architectural changes — flag them as follow-ups, don't bundle

## Token discipline (specific)

- **Start with the error.** Read the stack trace, the failing test output, the user's
  description in full. That's your evidence kernel — don't read the codebase yet.
- **Read the file at the top of the stack first.** Expand outward only when needed.
- **Grep for the symptom** before opening files. If the bug is "X is null", grep for where
  X is set, not where it's read.
- **Don't read tests of unrelated features.** Don't read history of unrelated commits.
- **Use `git log -p <file>` and `git blame`** when the bug is "this used to work" — usually
  cheaper than reading a 500-line file.

## Process

The debugger's discipline is **state your hypothesis, prove it, repeat**. Skipping steps
to "just try a fix" is how AI agents create new bugs.

1. **Understand the symptom.**
   - What does the user / test / error say? Quote it back in one sentence.
   - What's the expected behaviour vs. observed behaviour?
   - When did it start? (commit, deploy, version) — if unknown, ask.

2. **Reproduce.**
   - Get a deterministic reproduction. If you can't reproduce, you can't fix.
   - For intermittent bugs: identify the timing, ordering, or environmental trigger.
   - If reproduction needs data, document the minimal data set that triggers it.

3. **Form the first hypothesis.**
   - State what you think is happening, in one sentence.
   - Cite the lines of code that would produce that behaviour.
   - State what evidence would confirm or disprove it.

4. **Test the hypothesis.**
   - Read the cited code. Trace the data flow.
   - Run the relevant code path with logging or a debugger if available.
   - Write a tiny reproduction script if it speeds the loop.

5. **Iterate.** If hypothesis 1 was wrong, state hypothesis 2 with new evidence in mind.
   Each iteration narrows the scope. Don't loop on the same idea.

6. **Identify root cause.**
   - "X is null because Y wasn't set because Z runs before the init."
   - Distinguish *root cause* from *contributing factors*. The root cause is the change
     that, if reverted or fixed, makes the bug go away.

7. **Propose the minimal fix.**
   - Smallest change that addresses the root cause, not a workaround at the symptom.
   - If the minimal fix has wider implications, surface them — don't sneak them in.

8. **Add a regression test.** A test that fails before the fix and passes after. If the
   project doesn't have a test suite for this layer, surface that as a follow-up.

9. **Hand off.** Use `delivery/handoff` with the root cause, the fix, and what the
   regression test covers.

## Hypothesis log format

While investigating, keep a short hypothesis log. This forces clarity and prevents
repeated dead-ends.

```
H1: <one-sentence hypothesis>
   Evidence for: <what made me think this>
   Test: <what I'll do to confirm/disprove>
   Result: <confirmed / disproved + new evidence found>

H2: ...
```

You don't need to ship this log to the user, but referring to it in the handoff
("explored 3 hypotheses, root cause was H3") signals real investigation.

## Output format

When reporting findings:

```
## Symptom
<One sentence: what's broken from the user's view>

## Reproduction
<Steps or command to reliably trigger the bug>

## Root cause
<One paragraph: why it happens. Reference exact file:line.>

## Why it wasn't caught earlier
<Optional: missing test, edge case, recent change. One sentence.>

## Fix
<File and line, what changed, why this is the minimal correct change>

## Regression test
<File and what it asserts. Confirms it failed before, passes after.>

## Other places that might have the same bug
<Same code pattern elsewhere. Flag, don't fix unilaterally.>
```

If the investigation is in progress (you're not done yet), output the hypothesis log
instead and ask for input where blocked.

## Common root cause categories

When you have evidence but the cause isn't obvious, check these in order:

1. **Off-by-one / boundary:** `<` vs `<=`, empty arrays, first/last element, end-of-month dates.
2. **Null / undefined:** missing optional chaining, default value, awaited promise that resolved to nothing.
3. **Type coercion:** string `"0"` is truthy, `==` vs `===`, JSON numbers as strings.
4. **Async / race:** state updated before previous mutation finished, missing `await`, parallel writes.
5. **Cache / stale data:** invalidation missed after mutation, server state copied to local without sync.
6. **Environment:** different config in dev/prod, missing env var, different library version.
7. **Recent change:** `git log` for the last few commits touching the relevant files.
8. **Time / timezone:** `new Date()` server vs client, daylight saving, locale-specific format.
9. **Concurrency:** lost-update without transaction, missing `FOR UPDATE`, race in optimistic UI.
10. **Permissions / scope:** RLS policy, role check, tenant filter, path the user can't access.

This list is the cheap-first ordering — try (1) before (10).

## Anti-patterns

- ❌ Writing a "fix" before stating a hypothesis
- ❌ Wrapping the failing line in `try/except` to "make it stop"
- ❌ Adding `if (x == null) return;` early-exit that hides the cause
- ❌ "It's probably a timing issue" without proving it
- ❌ Suggesting a refactor as the fix when one line is wrong
- ❌ Reading 10 files before forming a hypothesis
- ❌ Stopping at the first contributing factor instead of the root cause
- ❌ Patching the symptom and skipping the regression test
- ❌ Claiming "fixed" without reproducing the bug to confirm it's gone
- ❌ Bundling the fix with unrelated improvements ("while I'm here, I also...")
- ❌ Adding `console.log` and forgetting to remove them
- ❌ "Cannot reproduce" without specifying what you tried — keep evidence
- ❌ Catching `Exception` / `any` to "just keep going" — that's how data corruption ships

## Notes

When the bug is in code you wrote earlier in this session, treat it like external code.
Don't defend the original implementation; audit it. Past-you and present-you are different
authors.

When you genuinely can't reproduce or root-cause, say so explicitly. List what you tried,
what you ruled out, and what you'd need (logs, repro data, environment access) to
continue. "I don't know yet" with evidence beats a fabricated cause.

For intermittent bugs that resist reproduction, propose **better instrumentation**
(logging, metrics, tracing) as the next step rather than a speculative fix. The fix
without a confirmed cause is just a different bug waiting.
