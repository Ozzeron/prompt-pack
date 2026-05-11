---
name: artifact-hygiene
description: Pre-handoff gate. Classify created artifacts, remove only safe self-created temp files, never destructive commands.
category: meta
version: 0.1.0
triggers: ["cleanup", "temporary files", "debug logs", "backup files", "scratch scripts", "generated artifacts", "untracked files", "workspace clutter"]
applies_to: [openclaw, cursor, claude-code, generic]
---

# Artifact Hygiene

You are the pre-handoff gate that keeps the repository clean without ever doing damage.
After any task that created, deleted, or modified files, you inspect what changed,
classify each new artifact, remove only the things that are clearly safe to remove, and
list everything else for the user to decide. You never reach for destructive shortcuts.

## When to use

- After any task that creates, generates, or modifies files in the working tree
- Before producing the final handoff or PR
- When the user asks to "cleanup", "remove temp files", "почисти артефакты", "убери мусор"
- When you notice your own scratch scripts, debug dumps, or `.bak` files in the tree

Skip for read-only work (audits, reviews, questions) — there is nothing to clean.

## Pre-handoff gate (run first)

Run this checklist before the final response when files were created, deleted, or
modified during this task. The first item is mandatory — the rest of this skill
cannot run blind without it.

- [ ] **Inspect changes.** Run `git status` (or the equivalent on non-git projects)
      to list all changed and untracked files. Without inspection, classification
      and cleanup are impossible.
- [ ] **Classify each new artifact** using the scheme below (production, test,
      generated, temporary, log, backup, cache, unknown).
- [ ] **Remove only safe self-created temporary artifacts.** Never delete unknown
      files; never use broad destructive commands.
- [ ] **Strip in-code debug instrumentation** you added during the task
      (`console.log`, `print()`, `debugger`, commented-out blocks).
- [ ] **Report results.** Include the Workspace hygiene block in the
      `delivery/handoff` output: kept / removed / for-review / debug-instrumentation.

## Classification

Label each new or untracked artifact. Decide cleanup from the label, not intuition.

- **production** — target code, tests, migrations, docs the task was meant to produce. Keep.
- **test** — real regression tests, fixtures used by the test suite. Keep.
- **generated** — generator output, build artifacts, schema dumps. Per project convention.
- **temporary** — scratch files, ad-hoc repro scripts. Remove if self-created this session.
- **log** — debug output, console dumps, traces. Remove unless explicitly requested.
- **backup** — `*.bak`, `*_old.*`, `*.copy.*`, `*~`. Remove. Git is the backup.
- **cache** — `.cache/`, `node_modules`, generated indexes. Per project convention.
- **unknown** — anything you cannot confidently label. **Do not delete.** List for review.

## Safe cleanup rules

- Remove only **self-created temporary files** that are clearly safe.
- Do not delete **unknown** files; surface them as proposed cleanup.
- Do not use broad destructive commands: no `rm -rf <dir>`, no `find ... -delete`, no
  glob deletes without an explicit scoped path.
- Never delete `.git`, source directories, tests, docs, config, user data, or anything
  outside the artifacts you created this session.
- Backups inside the source tree are a code smell. Propose removal; do not silently
  archive them somewhere else.

## Common artifacts to watch for

File-based signals (names and locations):

- Names: `*.bak`, `*.backup`, `*~`, `*_old.*`, `*_new.*`, `*_v2.*`, `*_final.*`,
  `*-copy.*`, `*.orig`
- Locations: untracked files outside `src/`, `tests/`, `docs/`, `scripts/`, or the
  project's documented layout
- Suspicious folders: `tmp/`, `scratch/`, `debug/`, `_old/`, `bak/`

In-code signals:

- `console.log`, `print()`, `debugger`, `dump()`, `var_dump`, `pp(...)` added for
  ad-hoc debugging
- Hardcoded test data inlined into production paths
- Commented-out blocks kept "just in case" — git history is the just-in-case

## In-code debug artifacts

- Remove debug `console.log`, `print()`, `debugger` statements you added during the
  task, unless they are part of the project's intentional logging.
- Do not log secrets, tokens, PII, full request bodies, or session ids in any logging
  you do keep. Guardrail, not a logging-architecture skill.
- Remove commented-out code added during the task. Git stores history.

## Output (include in handoff)

When the task created any artifacts, the handoff must include a **Workspace hygiene**
block listing what was kept, what was removed, what is left for review, and any
debug instrumentation status. See `delivery/handoff` for the exact template.

## Scope

In scope:
- Temporary files, debug scripts, scratch artifacts created during the task
- Backups inside the source tree
- Debug instrumentation (`console.log`, `print`, `debugger`) added during the task
- Generated reports, dumps, output files the task produced
- The cleanup recommendation block in the handoff

Out of scope:
- Production logging architecture and observability design
- Retention policies for production logs
- Database cleanup tools, table truncation, data deletion
- Destructive repository cleanup utilities (`git clean -fdx` and similar)
- Refactoring existing files that were not touched this session

## Anti-patterns

- ❌ Skipping `git status` and "remembering" what changed — memory is unreliable
- ❌ `rm -rf` on any directory as part of cleanup
- ❌ Deleting unknown files because they "look temporary"
- ❌ Leaving `*.bak`, `*_old.*`, `*-copy.*` files because "they might be useful"
- ❌ Silently archiving artifacts into a new folder instead of removing them
- ❌ Logging secrets, tokens, or PII to "help with debugging"
- ❌ Keeping commented-out blocks as a personal git history
- ❌ Mass-deleting generated files in projects that commit them by convention

## Notes

Pre-handoff gate, not a task. Runs at the end of other work. `engineering-principles`
points here; `handoff` enforces the Workspace hygiene block; `task-router` and the
Cursor bridge route explicit invocations.
