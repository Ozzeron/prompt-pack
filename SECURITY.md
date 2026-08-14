# Security

Agent skills are executable-by-proxy: whatever a SKILL.md says, an agent with tool access
may do. Independent scans of public skill ecosystems in early 2026 found prompt injection
and malicious payloads at scale — Snyk reported that 36.8% of 3,984 published skills carried
at least one security flaw and 13.4% a critical one, and a larger sweep found injection
patterns in roughly a quarter of 42k skills. So "it's just Markdown" is not a security
argument by itself. What follows is what this pack does and does not do.

## What installing a skill profile puts on your machine

Markdown only. Every file under `prompts/` is `SKILL.md` or a `references/*.md` file, and CI
fails the build if anything with an executable extension appears there (see
`checkNoExecutableCode` in `scripts/lint-skills.mjs`). There is no post-install step, no
network call, no telemetry, and no runtime of any kind. The installers copy files and
rewrite YAML frontmatter; `--dry-run` shows exactly what would be written, and CI asserts
that a dry run writes nothing.

## What DOES ship code, and only if you ask for it

The `enforcement` plugin (`hooks/`) installs three Node scripts that run as Claude Code
`PreToolUse` hooks. They are opt-in: the config lives at `hooks/enforcement.json`, not the
auto-discovered `hooks/hooks.json`, so no skill profile pulls them in. What they do:

- read the hook payload on stdin, match paths and command strings against fixed patterns
- write a permission decision (`deny` / `ask`) to stdout
- nothing else: no filesystem writes, no network, no shelling out. `guard-new-file` reads
  directory listings under the project root to find name collisions; that is the only
  filesystem access any of them makes.

Every guard fails open: on a malformed payload or an internal error it exits 0 with no
decision, so a bug cannot block your work. `scripts/test-hooks.mjs` covers the decisions
and the fail-open contract on Linux and Windows in CI.

## Prompt-injection posture

The skills instruct an agent to read your code. They never instruct it to fetch and follow
remote content, and none of them contains a URL an agent is told to obey. Three habits in
the pack reduce injection surface as a side effect:

- `meta/token-discipline` tells the agent what not to read, and the enforcement hook makes
  the worst of that architectural rather than advisory
- review and audit skills report findings; they do not apply fixes on their own authority
- `delivery/doc-writer` and `delivery/ai-agent-docs` produce drafts and explicitly do not
  commit, push, or publish

None of that makes the pack injection-proof. If your repo contains untrusted content
(vendored code, third-party issue text, generated fixtures), treat it as untrusted no matter
which skill is loaded.

## Auditing this pack yourself

The whole thing is meant to be read in one sitting: 23 skills, each SKILL.md capped at 240
lines by the linter, no minified or generated content. Useful commands:

```bash
npm run lint            # format contract, spec conformance, no-executable-code check
npm run test:hooks      # what the enforcement hooks actually decide
git log --oneline       # every change to every skill, with a version bump per edit
```

External scanners (Snyk's skill scanner, SkillSpector, and similar) run against this repo
like any other; the pack makes no claim to have been certified by any of them.

## Reporting a vulnerability

Open a GitHub issue for anything non-sensitive — a skill that could steer an agent into an
unsafe action, a hook that blocks or allows the wrong thing, an injection vector in a
reference file. For something you would rather not post publicly, use GitHub's private
vulnerability reporting on the repository.

Please include the skill or hook involved, the request that triggered it, and what the agent
did. A reproduction against `evals/fixtures/shop/` is ideal.
