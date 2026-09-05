#!/usr/bin/env bash
#
# Real-install content assertions for install.sh.
#
# CI otherwise only DRY-RUNS the installers, which proves the script parses its
# flags but never checks what a real install writes to disk. This script does
# real installs into fresh temp dirs and asserts the actual on-disk result:
# skill counts, rewritten-frontmatter shape, per-target task-router filtering,
# raw-body frontmatter stripping, idempotence, and backup behaviour.
#
# Usage: scripts/test-install-content.sh [repo-root]
#   repo-root defaults to the parent of this script's directory.
#
# bash 3.2 compatible (macOS default ships 3.2 due to the GPLv3 switch): no
# mapfile / readarray, no `declare -A`, no `${var^^}`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
INSTALL_SH="$REPO_ROOT/install.sh"

if [[ ! -f "$INSTALL_SH" ]]; then
  echo "ERROR: install.sh not found at $INSTALL_SH" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
fail() { echo "  FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "  ok:   $*"; }

# Checksum tool: shasum on macOS, sha256sum on Linux — either is fine, we only
# need a stable content hash, not a specific algorithm.
if command -v shasum >/dev/null 2>&1; then
  CKSUM="shasum"
elif command -v sha256sum >/dev/null 2>&1; then
  CKSUM="sha256sum"
else
  echo "ERROR: neither shasum nor sha256sum is available" >&2
  exit 1
fi

# Recursive checksum of a directory: hash the sorted list of per-file content
# hashes. Path-relative (uses `cd`) so it is stable regardless of the absolute
# temp dir and directly comparable across runs into the same tree.
tree_checksum() {
  local dir="$1"
  (
    cd "$dir" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do
      "$CKSUM" "$f"
    done
  ) | "$CKSUM" | awk '{print $1}'
}

# Run install.sh; on failure dump its output and return non-zero.
run_install() {
  local log
  log="$(mktemp)"
  if ! bash "$INSTALL_SH" "$@" >"$log" 2>&1; then
    echo "  install.sh $* FAILED:" >&2
    sed 's/^/    /' "$log" >&2
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
  return 0
}

# Count immediate subdirectories of a path (0 if it does not exist).
count_dirs() {
  [[ -d "$1" ]] || { echo 0; return; }
  find "$1" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' '
}

# Count immediate files matching a glob (0 if the dir does not exist).
count_files() {
  [[ -d "$1" ]] || { echo 0; return; }
  find "$1" -mindepth 1 -maxdepth 1 -type f -name "$2" | wc -l | tr -d ' '
}

# Emit the top-level YAML keys of a SKILL.md frontmatter block (lines between
# the first and second `---`), one key per line. The rewritten Agent-Skills
# frontmatter only ever carries single-line `name:` / `description:` scalars,
# so a column-0 `word:` match is an exact key detector here.
frontmatter_keys() {
  awk '
    BEGIN { fm = 0 }
    /^---[ \t]*$/ { fm++; next }
    fm == 1 {
      if (match($0, /^[A-Za-z_][A-Za-z0-9_]*:/)) {
        print substr($0, 1, RLENGTH - 1)
      }
    }
  ' "$1"
}

echo "Real-install content assertions (repo: $REPO_ROOT)"
echo "Work dir: $WORK"
echo

# ---------------------------------------------------------------------------
# TEST 1 — claude-skills / fullstack
#   - exactly 20 skill dirs (21 fullstack skills minus meta/task-router, which
#     native Skills targets filter out)
#   - task-router absent
#   - every installed SKILL.md frontmatter contains ONLY name + description
# ---------------------------------------------------------------------------
echo "TEST 1: claude-skills / fullstack"
T1="$WORK/t1"; mkdir -p "$T1"
if run_install --target claude-skills --profile fullstack --path "$T1" --force; then
  SK="$T1/.claude/skills"
  n="$(count_dirs "$SK")"
  if [[ "$n" == "20" ]]; then pass "20 skill dirs installed"; else fail "expected 20 skill dirs, got $n"; fi

  if [[ -d "$SK/task-router" ]]; then fail "task-router should be filtered from claude-skills"; else pass "task-router absent"; fi

  bad=""
  while IFS= read -r skmd; do
    keys="$(frontmatter_keys "$skmd" | LC_ALL=C sort | tr '\n' ',')"
    # Sorted keys of {name, description} render as "description,name,".
    if [[ "$keys" != "description,name," ]]; then
      bad="$bad ${skmd#"$SK/"}=[${keys}]"
    fi
  done < <(find "$SK" -mindepth 2 -maxdepth 2 -name SKILL.md | LC_ALL=C sort)
  if [[ -z "$bad" ]]; then pass "every SKILL.md frontmatter == {name, description}"; else fail "unexpected frontmatter keys:$bad"; fi
else
  fail "claude-skills/fullstack install failed"
fi
echo

# ---------------------------------------------------------------------------
# TEST 2 — openclaw
#   - minimal profile installs exactly 4 dirs under skills/
#   - task-router is NOT filtered for openclaw (it belongs to the subagent-
#     orchestration model). Assert with an explicit --skill meta/task-router.
# ---------------------------------------------------------------------------
echo "TEST 2: openclaw / minimal + task-router preservation"
T2="$WORK/t2"; mkdir -p "$T2"
if run_install --target openclaw --profile minimal --path "$T2" --force; then
  n="$(count_dirs "$T2/skills")"
  if [[ "$n" == "4" ]]; then pass "openclaw/minimal installed 4 dirs"; else fail "expected 4 openclaw dirs, got $n"; fi
else
  fail "openclaw/minimal install failed"
fi

T2B="$WORK/t2b"; mkdir -p "$T2B"
if run_install --target openclaw --skill meta/task-router --skill delivery/handoff --path "$T2B" --force; then
  if [[ -d "$T2B/skills/task-router" ]]; then pass "openclaw preserves meta/task-router"; else fail "openclaw dropped meta/task-router (should not be filtered)"; fi
else
  fail "openclaw task-router install failed"
fi
echo

# ---------------------------------------------------------------------------
# TEST 3 — raw / minimal
#   - exactly 4 .md files in docs/ai-rules/
#   - no YAML frontmatter delimiter line (a bare `---`) survives; the raw target
#     strips frontmatter and writes only the body
# ---------------------------------------------------------------------------
echo "TEST 3: raw / minimal"
T3="$WORK/t3"; mkdir -p "$T3"
if run_install --target raw --profile minimal --path "$T3" --force; then
  RD="$T3/docs/ai-rules"
  n="$(count_files "$RD" '*.md')"
  if [[ "$n" == "4" ]]; then pass "raw/minimal wrote 4 .md files"; else fail "expected 4 raw .md files, got $n"; fi

  fmfiles=""
  while IFS= read -r f; do
    if grep -qx -- '---' "$f"; then fmfiles="$fmfiles ${f#"$RD/"}"; fi
  done < <(find "$RD" -maxdepth 1 -type f -name '*.md')
  if [[ -z "$fmfiles" ]]; then pass "no frontmatter delimiter lines in raw bodies"; else fail "frontmatter delimiter found in:$fmfiles"; fi
else
  fail "raw/minimal install failed"
fi
echo

# ---------------------------------------------------------------------------
# TEST 4 — idempotence
#   Re-running claude-skills/fullstack with --force --no-backup must produce a
#   byte-identical tree (recursive checksum), and must leave no .bak-* clutter.
# ---------------------------------------------------------------------------
echo "TEST 4: idempotence (claude-skills / fullstack, --force --no-backup)"
T4="$WORK/t4"; mkdir -p "$T4"
if run_install --target claude-skills --profile fullstack --path "$T4" --force --no-backup \
   && run_install --target claude-skills --profile fullstack --path "$T4" --force --no-backup; then
  c1="$(tree_checksum "$T4/.claude/skills")"
  # Re-run a third time and compare to the second, guaranteeing steady state.
  run_install --target claude-skills --profile fullstack --path "$T4" --force --no-backup
  c2="$(tree_checksum "$T4/.claude/skills")"
  if [[ "$c1" == "$c2" ]]; then pass "re-install is idempotent ($c2)"; else fail "tree changed on re-install: $c1 != $c2"; fi

  nbak="$(find "$T4/.claude/skills" -maxdepth 1 -name '*.bak-*' | wc -l | tr -d ' ')"
  if [[ "$nbak" == "0" ]]; then pass "--no-backup left no .bak-* entries"; else fail "--no-backup left $nbak .bak-* entries"; fi
else
  fail "claude-skills/fullstack idempotence install failed"
fi
echo

# ---------------------------------------------------------------------------
# TEST 5 — backup
#   Re-running WITHOUT --no-backup (with --force) must rename existing skill
#   dirs to <name>.bak-<timestamp> before replacing them.
# ---------------------------------------------------------------------------
echo "TEST 5: backup (claude-skills / fullstack, --force, default backup)"
T5="$WORK/t5"; mkdir -p "$T5"
if run_install --target claude-skills --profile fullstack --path "$T5" --force \
   && run_install --target claude-skills --profile fullstack --path "$T5" --force; then
  nbak="$(find "$T5/.claude/skills" -maxdepth 1 -name '*.bak-*' | wc -l | tr -d ' ')"
  if [[ "$nbak" -ge 1 ]]; then pass "re-install created $nbak .bak-* backup entries"; else fail "expected .bak-* backup entries, found none"; fi
else
  fail "claude-skills/fullstack backup install failed"
fi
echo

# ---------------------------------------------------------------------------
# TEST 6 — codex / supabase (the Codex-native target)
#   Codex has no skill inheritance, so the installer carries the pack's
#   discipline through three mechanisms that only a real install can prove:
#   - agents/openai.yaml on the three foundation skills with implicit
#     invocation OFF (Codex lists them, only `$name` invokes them); no other
#     skill gets a policy file; task-router gets one with implicit ON.
#   - a compact AGENTS.md router bridge: every installed skill listed as
#     `$name`, every `$name` it mentions actually installed, composed flows
#     emitted only when every step is installed, placeholders substituted,
#     UTF-8 without BOM with the Cyrillic aliases intact.
#   - cross-skill links rewritten from ../../<category>/<name>/SKILL.md to
#     ../<name>/SKILL.md, and downgraded to a bare `$name` when the target is
#     not part of the profile, so no installed file links to a missing path.
#   Codex reads `name` to key the skill, so it must equal the directory name.
# ---------------------------------------------------------------------------
echo "TEST 6: codex / supabase"
T6="$WORK/t6"; mkdir -p "$T6"
if run_install --target codex --profile supabase --path "$T6" --force; then
  SK="$T6/.agents/skills"
  n="$(count_dirs "$SK")"
  if [[ "$n" == "14" ]]; then pass "14 skill dirs installed"; else fail "expected 14 skill dirs, got $n"; fi

  # name == directory name for every skill (Codex keys on `name`).
  bad=""
  while IFS= read -r skmd; do
    dir="$(basename "$(dirname "$skmd")")"
    nm="$(awk '/^---[ \t]*$/{fm++; next} fm==1 && /^name:/{sub(/^name:[ \t]*/, ""); gsub(/["'"'"']/, ""); print; exit}' "$skmd")"
    [[ "$nm" == "$dir" ]] || bad="$bad $dir=[$nm]"
  done < <(find "$SK" -mindepth 2 -maxdepth 2 -name SKILL.md | LC_ALL=C sort)
  if [[ -z "$bad" ]]; then pass "frontmatter name matches directory for every skill"; else fail "name/dir mismatch:$bad"; fi

  # Policy files: exactly the three foundation skills, implicit OFF.
  yaml_dirs="$(find "$SK" -mindepth 3 -maxdepth 3 -path '*/agents/openai.yaml' | sed -e "s|$SK/||" -e 's|/agents/openai.yaml$||' | LC_ALL=C sort | tr '\n' ',')"
  if [[ "$yaml_dirs" == "engineering-principles,reuse-before-create,token-discipline," ]]; then
    pass "openai.yaml only on the three foundation skills"
  else
    fail "unexpected openai.yaml set: [$yaml_dirs]"
  fi
  bad=""
  while IFS= read -r y; do
    grep -qx '  allow_implicit_invocation: false' "$y" || bad="$bad ${y#"$SK/"}"
    if [[ "$(head -c 3 "$y" | od -An -tx1 | tr -d ' \n')" == "efbbbf" ]]; then bad="$bad BOM:${y#"$SK/"}"; fi
  done < <(find "$SK" -name openai.yaml)
  if [[ -z "$bad" ]]; then pass "foundation policies disable implicit invocation, BOM-less"; else fail "policy problems:$bad"; fi

  # AGENTS.md bridge.
  AG="$T6/AGENTS.md"
  if [[ -f "$AG" ]]; then
    size="$(wc -c < "$AG" | tr -d ' ')"
    if (( size > 0 && size < 8192 )); then pass "AGENTS.md is compact ($size bytes)"; else fail "AGENTS.md size out of range: $size"; fi
    if [[ "$(head -c 3 "$AG" | od -An -tx1 | tr -d ' \n')" != "efbbbf" ]]; then pass "AGENTS.md has no BOM"; else fail "AGENTS.md starts with a UTF-8 BOM"; fi
    if ! grep -q 'PROMPT_PACK_' "$AG"; then pass "every template placeholder substituted"; else fail "unsubstituted placeholder in AGENTS.md"; fi
    if LC_ALL=C grep -qF 'проревьюй' "$AG"; then pass "Cyrillic aliases survived byte-exact"; else fail "Cyrillic alias missing or mangled in AGENTS.md"; fi

    missing=""
    while IFS= read -r d; do
      grep -qx -- "- \`\$${d}\`" "$AG" || missing="$missing $d"
    done < <(find "$SK" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | LC_ALL=C sort)
    if [[ -z "$missing" ]]; then pass "every installed skill is listed as \$name"; else fail "installed but not listed in AGENTS.md:$missing"; fi

    # supabase is used here because the template's static routing-discipline
    # text names $debugger, $repo-audit and $code-review, and all three are in
    # this profile, so every $name in the file must resolve to an installed dir.
    phantom=""
    while IFS= read -r ref; do
      [[ -d "$SK/$ref" ]] || phantom="$phantom $ref"
    done < <(grep -oE '\$[A-Za-z0-9._-]+' "$AG" | sed 's/^\$//' | LC_ALL=C sort -u)
    if [[ -z "$phantom" ]]; then pass "AGENTS.md names only installed skills"; else fail "AGENTS.md routes to skills that are not installed:$phantom"; fi

    if grep -q '^- Full PR review .*`\$code-review` then `\$security-review`' "$AG"; then pass "complete composed flow emitted"; else fail "Full PR review flow missing (both steps are installed)"; fi
    if ! grep -q 'Refactor execution' "$AG"; then pass "incomplete composed flow suppressed"; else fail "Refactor execution flow emitted although refactor-planner is not in supabase"; fi
  else
    fail "AGENTS.md not written"
  fi

  # Cross-links.
  if ! grep -rq '](\.\./\.\./' "$SK"; then pass "no ../../<category> links remain"; else fail "category-relative links survived the rewrite"; fi
  if grep -rqF '[`$engineering-principles`](../engineering-principles/SKILL.md)' "$SK"; then pass "links rewritten to \$name form"; else fail "expected rewritten link form not found"; fi
  dangling=""
  while IFS= read -r tgt; do
    [[ -d "$SK/$tgt" ]] || dangling="$dangling $tgt"
  done < <(grep -rhoE '\]\(\.\./[A-Za-z0-9._-]+/SKILL\.md\)' "$SK" | sed -E 's|^\]\(\.\./([A-Za-z0-9._-]+)/SKILL\.md\)$|\1|' | LC_ALL=C sort -u)
  if [[ -z "$dangling" ]]; then pass "every remaining link targets an installed skill"; else fail "dangling links to:$dangling"; fi
  # duplication-audit is referenced by an installed skill but not in supabase:
  # the link must have been downgraded to a bare token.
  if grep -rqF '`$duplication-audit`' "$SK" && ! grep -rq '](\.\./duplication-audit/SKILL\.md)' "$SK"; then
    pass "link to an uninstalled skill downgraded to a bare \$name"
  else
    fail "uninstalled-target link not downgraded (duplication-audit)"
  fi
else
  fail "codex/supabase install failed"
fi

T6B="$WORK/t6b"; mkdir -p "$T6B"
if run_install --target codex --skill meta/task-router --skill delivery/handoff --path "$T6B" --force; then
  SK="$T6B/.agents/skills"
  if [[ -f "$SK/task-router/agents/openai.yaml" ]] && grep -qx '  allow_implicit_invocation: true' "$SK/task-router/agents/openai.yaml"; then
    pass "task-router policy allows implicit invocation"
  else
    fail "task-router should carry allow_implicit_invocation: true"
  fi
  if [[ ! -e "$SK/handoff/agents" ]]; then pass "non-foundation skill gets no policy file"; else fail "handoff should not have agents/openai.yaml"; fi
else
  fail "codex task-router install failed"
fi
echo

# ---------------------------------------------------------------------------
# TEST 7 — codex / minimal, --scope user
#   User scope writes to $HOME/.agents/skills and must NOT write AGENTS.md:
#   user-level guidance lives in ~/.codex/AGENTS.md, not in a project file.
# ---------------------------------------------------------------------------
echo "TEST 7: codex / minimal --scope user"
T7="$WORK/t7"; mkdir -p "$T7/home" "$T7/proj"
log="$(mktemp)"
if HOME="$T7/home" bash "$INSTALL_SH" --target codex --profile minimal --scope user --path "$T7/proj" --force >"$log" 2>&1; then
  n="$(count_dirs "$T7/home/.agents/skills")"
  if [[ "$n" == "4" ]]; then pass "4 skill dirs under \$HOME/.agents/skills"; else fail "expected 4 user-scope dirs, got $n"; fi
  if [[ ! -e "$T7/proj/AGENTS.md" && ! -e "$T7/home/AGENTS.md" ]]; then pass "no AGENTS.md written in user scope"; else fail "user scope wrote an AGENTS.md"; fi
  if [[ ! -e "$T7/proj/.agents" ]]; then pass "nothing written into the project in user scope"; else fail "user scope wrote into the project path"; fi
else
  echo "  install.sh codex --scope user FAILED:" >&2; sed 's/^/    /' "$log" >&2
  fail "codex user-scope install failed"
fi
rm -f "$log"
echo

# ---------------------------------------------------------------------------
# TEST 8 — codex-agents-md / all (legacy single file)
#   The concatenated AGENTS.md must respect Codex's 32 KiB project-doc cap,
#   report what it skipped, and carry no relative SKILL.md links (every
#   referenced skill is inlined or absent, so a path link can only be broken).
# ---------------------------------------------------------------------------
echo "TEST 8: codex-agents-md / all"
T8="$WORK/t8"; mkdir -p "$T8"
log="$(mktemp)"
if bash "$INSTALL_SH" --target codex-agents-md --profile all --path "$T8" --force >"$log" 2>&1; then
  AG="$T8/AGENTS.md"
  size="$(wc -c < "$AG" | tr -d ' ')"
  if (( size <= 32768 )); then pass "AGENTS.md within 32 KiB ($size bytes)"; else fail "AGENTS.md exceeds 32 KiB: $size"; fi
  inc="$(grep -c '<!-- skill: ' "$AG" || true)"
  if (( inc >= 1 )); then pass "$inc skill(s) inlined"; else fail "no skill sections inlined"; fi
  if grep -q 'Skipped (would exceed Codex 32 KB limit)' "$log"; then pass "skipped skills reported"; else fail "23 skills cannot fit 32 KiB, yet nothing was reported skipped"; fi
  if ! grep -q '](\.\./' "$AG"; then pass "no relative SKILL.md links in the merged file"; else fail "relative SKILL.md links survived in the merged AGENTS.md"; fi
else
  echo "  install.sh codex-agents-md FAILED:" >&2; sed 's/^/    /' "$log" >&2
  fail "codex-agents-md/all install failed"
fi
rm -f "$log"
echo

# ---------------------------------------------------------------------------
echo "-----------------------------------------------------------------------"
if (( FAILURES == 0 )); then
  echo "ALL CONTENT ASSERTIONS PASSED"
  exit 0
else
  echo "$FAILURES content assertion(s) FAILED"
  exit 1
fi
