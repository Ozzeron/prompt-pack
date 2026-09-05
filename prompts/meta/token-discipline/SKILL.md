---
name: token-discipline
description: "Attention-budget rules for reading a codebase: what to open first, what never to open (dependency trees, build output, lockfiles, generated code), when to grep instead of read, and when widening the read is justified by correctness. Inherited by other skills rather than triggered on its own. Use when a skill Inherits section points here. Not for direct activation, and not a rule to minimise tokens."
license: MIT
metadata:
  pp-category: meta
  pp-version: "0.3.0"
  pp-activation: inherit-only
  pp-surfaces: "openclaw, cursor, claude-code, generic"
---

# Token Discipline

Tokens are an **attention budget, not a money budget**. The reason this skill exists is
not to save the user money — even on unlimited budgets, a context window stuffed with
low-signal files makes the model worse: it loses track of what matters, mixes patterns
from unrelated code, and hallucinates more confidently. Bigger context is not smarter
context.

The goal of this skill is **not** to make the agent read as little as possible. It is to
make the agent read **the right things first**, and only widen the read when correctness
demands it. Spend context where it buys reliability; do not spend it on noise.

This document is the single source of truth for "what an agent should and should not
read" while working on a task. Every other prompt in this pack inherits these rules.
Specific roles may add stricter rules on top, but never relax these.

## When to use

Always. This is a cross-cutting concern, not a triggered behaviour.

## Hard rules — never read

These directories and file types are noise by default. Do not read them raw under any
circumstance unless the user explicitly asks for it.

- Dependency caches: `node_modules/`, `vendor/`, `.venv/`, `venv/`, `__pycache__/`,
  `.gradle/`, `.cargo/`, `target/`, `Pods/`, `DerivedData/`
- Build outputs: `dist/`, `build/`, `out/`, `.next/`, `.nuxt/`, `.svelte-kit/`,
  `.turbo/`, `.parcel-cache/`, `coverage/`
- VCS internals: `.git/`, `.hg/`, `.svn/`
- Editor / OS: `.vscode/`, `.idea/`, `.DS_Store`, `Thumbs.db`
- Heavy binaries: `.exe`, `.dll`, `.so`, `.dylib`, `.bin`, `.iso`, `.zip`, `.tar`,
  `.7z`, `.dmg`, `.pdf` over 1MB unless required
- Heavy data: `.db`, `.sqlite`, `.parquet`, `.csv` over 1MB, `.jsonl` over 1MB,
  `.log` over 200KB

If you need information from one of these, use a tool (grep, jq, sqlite query, scripts) instead
of reading raw.

## Soft rules — read with care

- Files larger than **50KB**: state why you need them and ask before reading the full file.
  Prefer `read` with `offset`/`limit` or `grep` to extract the relevant section.
- Files larger than **200KB**: must use offset/limit or a script-based extraction. Never read
  in full unless the user has explicitly asked.
- Generated artifacts (`*.lock`, `*.min.js`, `*.bundle.js`): treat as binary, do not read.
- Migration files: read only the most recent ones unless the task is migration history.

## Before reading anything

1. Check if the answer is already in the conversation context or memory.
2. Check if a smaller artifact (README, package.json, schema file) already answers the question.
3. Choose the smallest read that answers the question. Use `grep` to locate before opening.

## When sampling isn't enough

Sampling 1–2 representative files saves tokens but is risky in older or inconsistent
codebases. If the samples disagree on conventions or patterns:

- Do not pick the prettier sample and run with it.
- Read **one additional canonical source**: a documented example, the design-system entry
  point, the project's `AGENTS.md` / `CLAUDE.md` / `README`, or the most recent file in
  the same archetype.
- If the conflict is genuine (the project itself is inconsistent), surface it as a finding
  rather than picking a side silently.

Names are not enough either. Before reusing or extending a component, function, or type,
grep for its imports / call sites to verify it does what its name suggests.

## Spawning subagents

Subagents inherit a fresh context. That is an opportunity, not a free pass.

- Use `context: "isolated"` (default) when the child can work from the task description alone.
  This is the cheapest option.
- Use `context: "fork"` only when the child needs the current transcript (e.g. continuing a
  multi-turn investigation). Forking duplicates the parent's context cost.
- Pass only the specific files / snippets the child needs as `attachments`, not whole directories.

## Tool output discipline

- Do not paste full tool outputs back into the response unless the user asked.
- Summarise verbose outputs (test runs, build logs) to the lines that matter.
- For long-running shells, use `yieldMs` and check back, instead of repeated polling.

## Weak-model adjustments

When the active model is small (Haiku, Sonnet, GPT-4o-mini, similar), tighten further:

- Halve the soft file-size threshold (25KB instead of 50KB).
- Always grep before reading.
- Resist multi-file reads in a single turn — sequence them.
- Prefer single-purpose subagents over giving one model a sprawling job.

## Anti-patterns

- ❌ "Let me read the whole repo to understand it" — pick the entry point and follow imports
- ❌ Reading `package.json` then `package-lock.json` then `pnpm-lock.yaml` — pick one
- ❌ Dumping a 500-line file when the user asked about one function
- ❌ Reading test files when the question is about the implementation
- ❌ Recursive directory listings without filters
- ❌ Re-reading the same file because the agent forgot what was in it (use memory or notes)

## Output expectation

You do not produce output for this skill directly. You internalise the rules and apply
them inside whatever role you are currently playing.
