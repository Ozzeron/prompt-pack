# Evals

Two layers, deliberately different in what they prove.

## 1. Description activation (automated, gates CI)

`descriptions/cases.yaml` holds labelled queries: each one names the skill that should win
when a host matches the request against the pack's descriptions. A case labelled for one
skill is a negative case for the other 22, so the near-miss pairs are covered by
construction — "review this PR" against "review the whole project", "design a schema"
against "review this migration", "write the README" against "write AGENTS.md".

```bash
npm run eval:descriptions              # deterministic proxy, offline
npm run eval:descriptions -- --verbose # per-case top-3 with scores
npm run eval:descriptions -- --llm     # real matcher via the claude CLI
npm run eval:descriptions -- --llm --limit 10
```

**What static mode proves:** every query has discriminating vocabulary in exactly one
description. That is the failure it was built to catch — a description that omits the words
users actually type ("containerise", "without downtime", "flaky in CI") cannot be matched by
any host, and seven of the pack's descriptions had exactly that gap when the suite was
first run.

**What static mode does not prove:** how a real host routes. It is BM25 over description
tokens, not a model. Treat 100% static as "no description is missing obvious vocabulary",
never as "activation is solved". Use `--llm` for that; it asks the actual matcher with the
same skill index a host loads, and it aborts loudly rather than reporting a number if the
CLI is unavailable or unauthenticated.

The floor in `scripts/eval-descriptions.mjs` is a ratchet. Raise it when descriptions
improve; never lower it to make a red run green.

Cases marked `llm_only: true` share no vocabulary with any description by nature (a query
like "total comes out 0 when there are clearly items" needs semantic inference). They are
skipped in static mode with a printed reason and still run under `--llm`.

## 2. Behavioural fixture (manual or LLM-judged, not in CI)

`fixtures/shop/` is a small repo with seven planted defects and `DEFECTS.yaml` as the
answer key. Nothing here builds or runs — the files exist to be read by a skill.

Protocol:

1. Install the pack into a scratch copy of `fixtures/shop/`.
2. Give the agent a real request, not a hint: "review this repo for security issues",
   "why is the orders endpoint slow", "add a helper to format dates".
3. Grade against `DEFECTS.yaml`: a hit names the file **and** the mechanism. "Consider
   reviewing authorization" is not a hit.
4. Record misses and over-reports, then fix the skill — not the fixture.

This layer is honest about being manual. Automating it means pinning a model version and
accepting run-to-run variance, which is a bigger commitment than the pack has made so far;
until then, no claim about behavioural pass rates belongs in the README.

D7 is a probe rather than a static finding: it only surfaces when the agent is asked to add
date handling to a repo that already depends on `date-fns`.
