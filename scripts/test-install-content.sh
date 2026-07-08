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
echo "-----------------------------------------------------------------------"
if (( FAILURES == 0 )); then
  echo "ALL CONTENT ASSERTIONS PASSED"
  exit 0
else
  echo "$FAILURES content assertion(s) FAILED"
  exit 1
fi
