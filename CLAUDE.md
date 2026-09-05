# CLAUDE.md

Project instructions live in [AGENTS.md](AGENTS.md) — the cross-tool standard, read natively
by Codex, Cursor, Copilot, and Gemini CLI. Claude Code does not read `AGENTS.md`
automatically, so this file imports it rather than duplicating it. Two copies of the same
rules drift; one of them is then wrong.

@AGENTS.md

## Claude Code specifics

- The pack installs into Claude Code as a plugin: `/plugin marketplace add Ozzeron/prompt-pack`
  then `/plugin install <profile>@prompt-pack`. Pick exactly one skill profile — they overlap
  by design.
- `enforcement@prompt-pack` is a separate, opt-in plugin: the three `PreToolUse` guards in
  `hooks/`. Layer it on top of a skill profile; no profile installs it implicitly.
- When testing a local change, add the marketplace from the working tree (`/plugin marketplace
  add ./`) rather than from GitHub, and remove it afterwards so the published version is what
  stays installed.
- `meta/task-router` is excluded from every native install on purpose. Claude Code routes by
  description; a router skill on top of that is a second, worse matcher.
