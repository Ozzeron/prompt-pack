# Changelog

All notable changes to prompt-pack. Full release notes with details live in
[GitHub Releases](https://github.com/Ozzeron/prompt-pack/releases); this file
is the condensed history.

## Unreleased

- Docs: the repo is a working [skills.sh](https://skills.sh) source. `npx skills add
  Ozzeron/prompt-pack` is documented as the no-clone path for Cursor / Codex / Copilot /
  OpenClaw, with the two verified differences from `--target agents` (task-router included,
  cross-skill links copied verbatim so 62 of 81 do not resolve in the flat tree).

## v0.5.0 - 2026-09-05 — Agent Skills spec conformance

### Agent Skills spec conformance (breaking for anything that read the old frontmatter)

- Frontmatter now carries only spec keys. `category`, `version`, `triggers`, and
  `applies_to` moved under `metadata` as `pp-category`, `pp-version`, `pp-surfaces`
  (strings, `pp-`-prefixed to avoid cross-publisher collisions); `license: MIT` added.
- `triggers` retired. Its phrases moved into `description`, which is what native hosts
  match on. `pp-activation` (`native` / `inherit-only` / `legacy`) replaces the old
  trigger-list conventions; `meta/task-router` is now explicitly `legacy`.
- All 23 descriptions rewritten for activation: what it does + `Use when …` + a negative
  trigger naming the sibling skill, 384-452 chars against a new 500-char budget (was a
  120-char cap that could not hold what + when + when-not).
- `delivery/doc-writer` no longer claims `AGENTS.md` / `CLAUDE.md`; that work belongs to
  `delivery/ai-agent-docs`, which already existed. Duplicate capability removed, not
  duplicated.
- Progressive disclosure: nine skills moved templates, coverage passes, and per-branch
  checklists into `references/*.md`, each linked from `SKILL.md` with an explicit load
  condition. The five root-level `EXAMPLES.md` files moved to `references/EXAMPLES.md`.
  Core `SKILL.md` budget is now 240 lines (was 310).
- Linter: allowed-top-level-key check, required `pp-*` metadata, description length floor
  and ceiling, `Use when` clause, negative trigger, ASCII-only descriptions, reference
  files linked with a condition, no dead or root-level reference files, no executable code
  under `prompts/`. Version gate reads `metadata.pp-version` with a fallback to the old
  key so PRs opened across the migration still compare correctly.

### New: enforcement hooks (opt-in)

- `enforcement@prompt-pack` plugin registers three `PreToolUse` guards:
  `guard-noise-reads` (denies dependency trees, git internals, lockfiles, minified
  bundles; asks on build output), `guard-new-file` (asks when a new source file duplicates
  an existing name), `guard-new-dependency` (asks when an install command names a package).
- Opt-in by design: config at `hooks/enforcement.json`, not the auto-discovered
  `hooks/hooks.json`, so no skill profile pulls hooks in. All guards fail open.
- `scripts/test-hooks.mjs`: 24 cases against real hook processes, including the fail-open
  contract and near misses that must not fire. CI runs it on Ubuntu and Windows.

### New: evals

- `evals/descriptions/cases.yaml` — 59 labelled queries; each is a positive for one skill
  and a negative for the other 22. `npm run eval:descriptions` scores top-1 accuracy
  offline (BM25 over descriptions, negative clause scored as an exclusion) and gates CI at
  95%. `--llm` asks the real matcher through the claude CLI and aborts rather than
  reporting a number when the CLI is unavailable.
- First run scored 84.7%; every miss was a description missing a word users type
  ("containerise", "without downtime", "flaky", "only in CI", "slow UI", "full audit",
  "untangle"). Nine descriptions fixed, now 58/58.
- `evals/fixtures/shop/` — small repo with seven planted defects and `DEFECTS.yaml` as the
  answer key. Graded by hand; no behavioural pass rate is published.

### Repo

- `AGENTS.md` (this repo's own agent instructions) + `CLAUDE.md` importing it — the pack
  now dogfoods `delivery/ai-agent-docs`.
- `SECURITY.md`: what installing actually puts on your machine, the injection posture, and
  how to audit the pack.
- README/USAGE/CONTRIBUTING/PROMPT-FORMAT rewritten around the standard: unverifiable
  hardening claims replaced with the commands that back them, flat installer targets
  documented as unable to carry `references/`, legacy targets marked maintained-not-developed.

- Host directory map (USAGE, September 2026): `agents` is read by OpenClaw as well as
  Cursor, Codex, and Copilot; Cursor and Copilot also scan `.claude/skills/`, so one skill
  root per repo is now the documented rule. Codex activation notes (`$skill`, `/skills`,
  `agents/openai.yaml` policy) and the moved Codex docs link.
- Real-matcher eval run end to end for the first time: `npm run eval:descriptions -- --llm`
  scores 59/59 (static proxy 58/58; one case is semantic-only by design).
- CI: `actions/checkout` and `actions/setup-node` pinned to v7, ShellCheck action pinned
  to a release tag instead of `master`. `yaml` dev dependency 2.8 -> 2.9.
- Codex target now has real-install content assertions (`scripts/test-install-content.sh`
  tests 6-8): foundation `agents/openai.yaml` policies, AGENTS.md bridge honesty (every
  installed skill listed, no route to an uninstalled one, composed flows only when complete,
  BOM-less with Cyrillic aliases intact), cross-link rewrite with no dangling targets,
  `--scope user` writes no AGENTS.md, legacy `codex-agents-md` stays under 32 KiB. `codex`
  joins the sh/ps1 byte-parity matrix. These are the deterministic checks the May Codex
  regression brief listed as CI candidates.

### Earlier in this cycle


- Claude Code plugin marketplace: `.claude-plugin/marketplace.json` at the repo root
  exposes six profile plugins (`minimal`, `nextjs`, `backend`, `supabase`, `fullstack`,
  `all-skills`) — `/plugin marketplace add Ozzeron/prompt-pack` then
  `/plugin install <profile>@prompt-pack`, no clone or installer run needed.
  `meta/task-router` is excluded from every plugin (native skill discovery routes).
- New installer target `claude-skills`: Claude Code native Agent Skills
  (`.claude/skills/<name>/SKILL.md`, `--scope user` for `~/.claude/skills/`).
  Legacy `claude-code` subagents target unchanged; prefer `claude-skills`.
- Lint: private leakage terms moved to a SHA-256 hash blocklist
  (`scripts/leakage-hashes.json`); inline-ref and description-collision checks added.
- CI: real-install assertions, Windows PowerShell 5.1 job, cross-shell parity job,
  skill version-bump gate.

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
