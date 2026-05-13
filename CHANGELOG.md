# Changelog

## v0.4.1 - 2026-05-13

- Fixed Codex partial-profile installs so cross-skill links only stay as markdown links when the target skill is installed; missing targets are rendered as plain `$skill` references.
- Added Codex `AGENTS.md` composed-flow routing for full PR review, schema change PR, and refactor execution.
- Tightened Codex routing disambiguation so ambiguous bug fixes, review requests, and migrations ask for the missing signal before selecting a specialist skill.
