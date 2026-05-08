#!/usr/bin/env bash
#
# Install prompt-pack skills into a project directory.
#
# Usage:
#   ./install.sh --target <cursor|claude-code|codex|openclaw|raw> [--profile <name>] [--path <dir>] [--force] [--list]
#
# Profiles:
#   minimal    — 4 always-on meta skills + handoff
#   nextjs     — minimal + frontend-feature, ui-designer, code-review, debugger, test-writer
#   backend    — minimal + backend-api, database-schema, database-migrations, reviews, test-writer
#   supabase   — backend + postgres-supabase
#   fullstack  — almost everything
#   all        — every skill in prompts/
#
# Examples:
#   ./install.sh --target cursor --profile minimal
#   ./install.sh --target codex --profile supabase --path ~/code/project-a
#   ./install.sh --list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_ROOT="$SCRIPT_DIR/prompts"

TARGET=""
PROFILE="minimal"
TARGET_PATH="$(pwd)"
FORCE=0
LIST=0
EXPLICIT_SKILLS=()

# ---------------------------------------------------------------------------
# Profile definitions
# ---------------------------------------------------------------------------

profile_skills() {
  case "$1" in
    minimal)
      cat <<EOF
meta/engineering-principles
meta/reuse-before-create
meta/token-discipline
delivery/handoff
EOF
      ;;
    nextjs)
      cat <<EOF
meta/engineering-principles
meta/reuse-before-create
meta/token-discipline
delivery/handoff
architecture/frontend-feature
interface/ui-designer
review/code-review
review/debugger
delivery/test-writer
EOF
      ;;
    backend)
      cat <<EOF
meta/engineering-principles
meta/reuse-before-create
meta/token-discipline
delivery/handoff
architecture/backend-api
architecture/database-schema
architecture/database-migrations
review/code-review
review/database-review
review/security-review
review/debugger
delivery/test-writer
EOF
      ;;
    supabase)
      cat <<EOF
meta/engineering-principles
meta/reuse-before-create
meta/token-discipline
delivery/handoff
architecture/backend-api
architecture/database-schema
architecture/database-migrations
architecture/postgres-supabase
review/code-review
review/database-review
review/security-review
review/debugger
delivery/test-writer
EOF
      ;;
    fullstack)
      cat <<EOF
meta/engineering-principles
meta/reuse-before-create
meta/token-discipline
meta/task-router
architecture/backend-api
architecture/frontend-feature
architecture/database-schema
architecture/database-migrations
architecture/postgres-supabase
architecture/refactor-planner
interface/ui-designer
review/code-review
review/database-review
review/security-review
review/debugger
delivery/handoff
delivery/test-writer
delivery/doc-writer
EOF
      ;;
    all)
      ( cd "$PROMPTS_ROOT" && find . -name SKILL.md -type f | sed -E 's|^\./||; s|/SKILL\.md$||' | sort )
      ;;
    *)
      echo "Unknown profile: $1" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

show_list() {
  echo
  echo "Available profiles:"
  for p in minimal nextjs backend supabase fullstack all; do
    count=$(profile_skills "$p" | wc -l | tr -d ' ')
    printf "  %-10s %s skills\n" "$p" "$count"
  done

  echo
  echo "Available skills:"
  ( cd "$PROMPTS_ROOT" && find . -name SKILL.md -type f | sed -E 's|^\./|  |; s|/SKILL\.md$||' | sort )

  echo
  echo "Available targets:"
  for t in cursor claude-code codex openclaw raw; do
    echo "  $t"
  done
  echo
}

# Strip YAML frontmatter from a SKILL.md and return the body.
get_body() {
  local src="$1"
  # awk: skip lines until the second `---` is seen, then print the rest.
  awk '
    BEGIN { in_fm = 0; done = 0 }
    !done && /^---$/ {
      if (in_fm == 0) { in_fm = 1; next }
      else { done = 1; next }
    }
    !done { next }
    done { print }
  ' "$src"
}

confirm_overwrite() {
  local path="$1"
  if [[ -e "$path" && $FORCE -eq 0 ]]; then
    read -r -p "  Overwrite $path? [y/N] " resp
    [[ "$resp" =~ ^[yY]$ ]]
  else
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Installers
# ---------------------------------------------------------------------------

install_cursor() {
  local rules_dir="$TARGET_PATH/.cursor/rules"
  echo
  echo "Installing to $rules_dir"
  echo
  mkdir -p "$rules_dir"

  for skill in "${SKILLS[@]}"; do
    local name="${skill##*/}"
    local src="$PROMPTS_ROOT/$skill/SKILL.md"
    local dest="$rules_dir/$name.md"

    if [[ ! -f "$src" ]]; then echo "  Missing: $src" >&2; continue; fi
    confirm_overwrite "$dest" || { echo "  Skipped."; continue; }
    cp "$src" "$dest"
    echo "  Wrote $dest"
  done

  echo
  echo "Done. Reload your Cursor window to pick up the new rules."
  echo "Tip: open a rule file and add 'alwaysApply: true' to the frontmatter for always-on rules."
}

install_claude_code() {
  local agents_dir="$TARGET_PATH/.claude/agents"
  echo
  echo "Installing to $agents_dir"
  echo
  mkdir -p "$agents_dir"

  for skill in "${SKILLS[@]}"; do
    local name="${skill##*/}"
    local src="$PROMPTS_ROOT/$skill/SKILL.md"
    local dest="$agents_dir/$name.md"

    if [[ ! -f "$src" ]]; then echo "  Missing: $src" >&2; continue; fi
    confirm_overwrite "$dest" || { echo "  Skipped."; continue; }
    cp "$src" "$dest"
    echo "  Wrote $dest"
  done

  echo
  echo "Done. Claude Code will pick up the agents on next start."
}

install_codex() {
  local agents_file="$TARGET_PATH/AGENTS.md"
  local size_limit=$((32 * 1024))
  echo
  echo "Building $agents_file from ${#SKILLS[@]} skills"
  echo

  if [[ -e "$agents_file" && $FORCE -eq 0 ]]; then
    read -r -p "$agents_file exists. Overwrite? [y/N] " resp
    [[ "$resp" =~ ^[yY]$ ]] || { echo "Aborted."; return 1; }
  fi

  local tmp
  tmp="$(mktemp)"
  {
    echo "# Agent Instructions"
    echo
    echo "Generated by prompt-pack install.sh. Do not edit by hand; re-run the"
    echo "installer to update. Source: https://github.com/Ozzeron/prompt-pack"
    echo
  } > "$tmp"

  local skipped=()
  for skill in "${SKILLS[@]}"; do
    local src="$PROMPTS_ROOT/$skill/SKILL.md"
    if [[ ! -f "$src" ]]; then echo "  Missing: $src" >&2; continue; fi

    local body
    body="$(get_body "$src")"
    local section
    section="$(printf '\n---\n\n<!-- skill: %s -->\n%s\n' "$skill" "$body")"

    local current
    current="$(wc -c < "$tmp" | tr -d ' ')"
    local addition=${#section}
    if (( current + addition > size_limit )); then
      skipped+=("$skill")
      continue
    fi

    printf '%s' "$section" >> "$tmp"
    echo "  Included $skill"
  done

  mv "$tmp" "$agents_file"
  local final_size
  final_size="$(wc -c < "$agents_file" | tr -d ' ')"
  echo
  echo "Wrote $agents_file ($((final_size / 1024)) KB / 32 KB limit)"

  if (( ${#skipped[@]} > 0 )); then
    echo
    echo "Skipped (would exceed Codex 32 KB limit):"
    for s in "${skipped[@]}"; do echo "  $s"; done
    echo
    echo "Tip: pick a smaller profile or use directory-specific AGENTS.override.md files."
  fi
}

install_openclaw() {
  local skills_dir="$TARGET_PATH/skills"
  echo
  echo "Installing skill directories to $skills_dir"
  echo
  mkdir -p "$skills_dir"

  for skill in "${SKILLS[@]}"; do
    local name="${skill##*/}"
    local src="$PROMPTS_ROOT/$skill"
    local dest="$skills_dir/$name"

    if [[ ! -d "$src" ]]; then echo "  Missing: $src" >&2; continue; fi
    if [[ -d "$dest" && $FORCE -eq 0 ]]; then
      read -r -p "  Overwrite $dest? [y/N] " resp
      [[ "$resp" =~ ^[yY]$ ]] || { echo "  Skipped."; continue; }
      rm -rf "$dest"
    fi
    cp -R "$src" "$dest"
    echo "  Wrote $dest"
  done

  echo
  echo "Done."
}

install_raw() {
  local raw_dir="$TARGET_PATH/docs/ai-rules"
  echo
  echo "Installing raw markdown bodies to $raw_dir"
  echo
  mkdir -p "$raw_dir"

  for skill in "${SKILLS[@]}"; do
    local name="${skill##*/}"
    local src="$PROMPTS_ROOT/$skill/SKILL.md"
    local dest="$raw_dir/$name.md"

    if [[ ! -f "$src" ]]; then echo "  Missing: $src" >&2; continue; fi
    confirm_overwrite "$dest" || { echo "  Skipped."; continue; }
    get_body "$src" > "$dest"
    echo "  Wrote $dest"
  done

  echo
  echo "Done. Paste any of these into your AI tool's system-prompt / custom-instructions field."
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)   TARGET="$2"; shift 2 ;;
    --profile)  PROFILE="$2"; shift 2 ;;
    --path)     TARGET_PATH="$2"; shift 2 ;;
    --skill)    EXPLICIT_SKILLS+=("$2"); shift 2 ;;
    --force)    FORCE=1; shift ;;
    --list)     LIST=1; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if (( LIST == 1 )); then show_list; exit 0; fi

if [[ -z "$TARGET" ]]; then
  echo "Error: --target is required (cursor / claude-code / codex / openclaw / raw)." >&2
  echo "Run with --list to see available profiles and skills." >&2
  exit 1
fi

case "$TARGET" in
  cursor|claude-code|codex|openclaw|raw) ;;
  *) echo "Error: invalid --target '$TARGET'" >&2; exit 1 ;;
esac

TARGET_PATH="$(cd "$TARGET_PATH" 2>/dev/null && pwd || { echo "Error: path does not exist: $TARGET_PATH" >&2; exit 1; })"

if (( ${#EXPLICIT_SKILLS[@]} > 0 )); then
  SKILLS=("${EXPLICIT_SKILLS[@]}")
else
  mapfile -t SKILLS < <(profile_skills "$PROFILE")
fi

if (( ${#SKILLS[@]} == 0 )); then
  echo "Error: no skills resolved (profile=$PROFILE)." >&2
  exit 1
fi

echo "Target:  $TARGET"
if (( ${#EXPLICIT_SKILLS[@]} > 0 )); then
  echo "Profile: custom (${#EXPLICIT_SKILLS[@]} skills)"
else
  echo "Profile: $PROFILE"
fi
echo "Path:    $TARGET_PATH"
echo "Skills:  ${#SKILLS[@]}"

case "$TARGET" in
  cursor)      install_cursor ;;
  claude-code) install_claude_code ;;
  codex)       install_codex ;;
  openclaw)    install_openclaw ;;
  raw)         install_raw ;;
esac
