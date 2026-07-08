# Changelog

All notable changes to prompt-pack. Full release notes with details live in
[GitHub Releases](https://github.com/Ozzeron/prompt-pack/releases); this file
is the condensed history.

## v0.4.1 - 2026-05-13

- Fixed Codex partial-profile installs so cross-skill links only stay as markdown links when the target skill is installed; missing targets are rendered as plain `$skill` references.
- Added Codex `AGENTS.md` composed-flow routing for full PR review, schema change PR, and refactor execution.
- Tightened Codex routing disambiguation so ambiguous bug fixes, review requests, and migrations ask for the missing signal before selecting a specialist skill.

## v0.4.0 - 2026-05-12 — Skills-first installer

- New targets: `cursor` (Cursor 2.4+ Skills-native: `.cursor/skills/` + three always-on foundation rules), `cursor-foundation` (foundation rules only, layer on `agents`), `agents` (universal `.agents/skills/` for Cursor 2.4+, Codex CLI, GitHub Copilot).
- Previous `cursor` behaviour preserved as legacy `cursor-rules` target.
- `meta/task-router` filtered from native-Skills targets — host skill discovery replaces the routing role.
- Cross-skill links rewritten for flat Agent Skills layouts; YAML descriptions safely quoted; docs cover the `codex` + `cursor` duplicate-roots risk.

## v0.3.0 - 2026-05-11

- New skill: `infra/docker` — Dockerfile/compose discipline (multi-stage, no `FROM latest`, no secrets in ARG/ENV, non-root final stage), stack-agnostic, with annotated EXAMPLES.md.
- `architecture/frontend-feature` made framework-neutral: React/Next, Vue/Nuxt, Svelte/SvelteKit, Angular vocabulary table + side-effect discipline section.
- `infra` category added to the format schema and linter.

## v0.2.x - 2026-05-10 — Codex-native line

- **v0.2.8** — `--no-backup` flag for clean re-installs.
- **v0.2.7** — "Yes to all" replace prompt + post-install tip.
- **v0.2.6** — Cross-skill refs rendered as clickable markdown links.
- **v0.2.5** — Codex foundation skills switched to explicit-only invocation (`openai.yaml` policy).
- **v0.2.4** — Codex cross-skill link rewrite for the flat `.agents/skills/` layout.
- **v0.2.3** — macOS awk compatibility fix in installer.
- **v0.2.2** — Codex audit: dynamic routing rules in generated AGENTS.md.
- **v0.2.1** — ShellCheck CI fix.
- **v0.2.0** — Codex-native skills target: `--target codex` writes `.agents/skills/<name>/SKILL.md` + compact routing AGENTS.md (previously everything was crammed into one 32 KiB AGENTS.md — only 5 of 21 fullstack skills fit). New `--scope repo|user` flag. Single-file installer preserved as `codex-agents-md`.

## v0.1.x - 2026-05-09 — Foundation

- **v0.1.10** — Cursor delivery + empirical hardening: fixes from the first field tests on real codebases (encoding, Cursor format issues).
- **v0.1.9** — macOS install fix (bash 3.2 compatibility).
- **v0.1.8** — Positioning patch: "discipline pack, not prompt directory" framing.
- **v0.1.7** — Typography micro-patch.
- **v0.1.6** — Release-hygiene patch.
- **v0.1.5** — Behaviour patch: Preflight checklist pilot in `review/code-review`.
- **v0.1.4** — Polish patch.
- **v0.1.3** — Convention discovery + dependency hygiene rules in architecture skills.
- **v0.1.2** — Trigger discipline: `inherit-only` invariant introduced and lint-enforced.
- **v0.1.1** — Release tag sync + expanded lint quality gates.
- **v0.1.0** — Initial release: 21 skills, format schema, linter, bash + PowerShell installers, CI.
