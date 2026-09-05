# prompt-pack

A curated Agent Skills library for AI coding assistants. This repo ships prompts, not an
application: nothing here builds or runs, so "working" means the linter, the hook tests, and
the activation eval pass.

## Stack

Markdown (the product) · Node ≥18 + `yaml` (tooling only) · Bash + PowerShell 5.1
installers · GitHub Actions

## Triggers

- **When the user asks to add or change a skill** → read
  [`docs/PROMPT-FORMAT.md`](docs/PROMPT-FORMAT.md) first, then the closest existing skill in
  the same category as a shape reference. Every skill edit needs a `metadata.pp-version` bump
  in the same change; CI fails without it.
- **When you touch a `description:` line** → it is the activation surface, not a summary.
  Keep the what + `Use when …` + `Not for …` shape, keep it ASCII, and add or update cases in
  `evals/descriptions/cases.yaml` (one obvious query, one non-obvious phrasing, one near-miss
  that must route elsewhere). Then run `npm run eval:descriptions`.
- **When a `SKILL.md` crosses ~240 lines** → do not trim wording. Move conditional material
  (templates, per-branch checklists, worked examples) into `references/*.md` and link it with
  an explicit load condition: "read X **when** Y".
- **When you change anything under `hooks/`** → `npm run test:hooks` must cover the new
  decision AND the near-miss that must NOT fire. Guards fail open by contract; never add a
  code path that can throw past `guard()`.
- **When you change `install.sh`** → make the identical change in `install.ps1`. CI compares
  the two trees byte-for-byte on Windows, and the historical failure class is text encoding
  (BOM, CRLF, a regex eating the blank line after frontmatter).
- **When adding a skill to a profile** → update both installers and the README profile table;
  the linter cross-checks all three and the counts.

## Commands

```bash
npm run lint                 # format contract, spec conformance, cross-checks
npm run eval:descriptions    # activation eval (deterministic; gates CI at 95%)
npm run test:hooks           # what the enforcement hooks actually decide
npm run test:install-content # real installs into temp dirs, on-disk assertions
npm run check:version-bump   # every changed skill bumped its version
./install.sh --list          # profiles and targets
```

## Conventions

- Frontmatter carries only spec keys (`name`, `description`, `license`, `compatibility`,
  `metadata`, `allowed-tools`). Pack fields live under `metadata` as `pp-`-prefixed strings.
- No executable code under `prompts/` — the linter enforces it, and SECURITY.md relies on it.
- Skills reference each other as `` `category/name` `` in backticks and link relatively
  (`../../meta/token-discipline/SKILL.md`); the linter resolves every one.
- Code-creating skills must declare `meta/reuse-before-create` in `## Inherits`.
- Section order in non-meta skills: When to use → Scope → Inherits → Token discipline →
  (Process) → Output format → Anti-patterns.
- Rules that must survive context compression go in a `## Preflight` checklist near the top,
  not as prose in the middle. See `prompts/review/code-review/SKILL.md`.
- No private names, employer names, or personal handles anywhere; the blocklist is hashed in
  `scripts/leakage-hashes.json` and the linter checks against it.
- ASCII in descriptions and installer-rewritten lines. Multilingual routing lives in
  `templates/cursor-bridge.mdc`, which is copied byte-for-byte for that reason.

## Forbidden zones

- `node_modules/` — do not read or edit
- `prompts/**/references/EXAMPLES.md` — worked examples; edit only alongside the skill they
  illustrate
- `evals/fixtures/shop/` — defects are planted on purpose. Fix the skill, never the fixture
- `templates/cursor-bridge.mdc` — byte-sensitive (PowerShell 5.1 encoding); change only with
  the cross-shell parity job green
- Release notes and tags — publishing is a human decision, not an agent one
