#!/usr/bin/env bash
#
# Install prompt-pack skills into a project directory.
#
# Usage:
#   ./install.sh --target <cursor|claude-code|codex|codex-agents-md|openclaw|raw> [--profile <name>] [--path <dir>] [--scope <repo|user>] [--force] [--list]
#
# Targets:
#   cursor          - .cursor/rules/*.mdc + alwaysApply bridge router.
#   claude-code     - .claude/agents/*.md.
#   codex           - Codex-native: .agents/skills/<name>/SKILL.md + a
#                     compact AGENTS.md router/bridge. Use --scope user to
#                     write to $HOME/.agents/skills/ instead.
#   codex-agents-md - Legacy single-file install: concatenate skills into
#                     one AGENTS.md (capped at 32 KiB). Prefer --target codex.
#   openclaw        - skills/<name>/ (full SKILL.md + sidecars).
#   raw             - docs/ai-rules/<name>.md (loose markdown bodies).
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
#   ./install.sh --target cursor --profile fullstack --dry-run
#   ./install.sh --list
#
# Safety:
#   - Without --force, every overwrite is confirmed interactively.
#   - With --force, existing FILES are replaced; existing DIRECTORIES (only used
#     by the openclaw target) are renamed to <name>.bak-<timestamp> before being
#     replaced, never deleted outright.
#   - --dry-run reports what would be written without making changes.
#   - The script warns if the project already has agent-config files or if its
#     git working tree is dirty.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_ROOT="$SCRIPT_DIR/prompts"

TARGET=""
PROFILE="minimal"
TARGET_PATH="$(pwd)"
SCOPE="repo"
FORCE=0
DRY_RUN=0
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
review/repo-audit
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
review/repo-audit
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
review/repo-audit
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
review/repo-audit
review/frontend-audit
review/database-review
review/security-review
review/duplication-audit
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
  for t in cursor claude-code codex codex-agents-md openclaw raw; do
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

# Returns 0 if we should write to the path (either it doesn't exist, or the user
# confirmed overwrite, or --force is set; in the --force case the existing file is
# backed up first).
handle_existing_file() {
  local path="$1"
  [[ ! -e "$path" ]] && return 0

  if (( FORCE == 0 )); then
    read -r -p "  Overwrite $path? [y/N] " resp
    [[ "$resp" =~ ^[yY]$ ]] || return 1
    return 0
  fi

  local backup
  backup="$(backup_file "$path")"
  [[ -n "$backup" ]] && echo "  Backed up to $backup"
  return 0
}

# Rename an existing directory to <name>.bak-<timestamp>. Echoes the backup path,
# or prints nothing if the source did not exist.
backup_directory() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return 0

  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  local backup="${dir}.bak-${stamp}"
  local i=1
  while [[ -e "$backup" ]]; do
    backup="${dir}.bak-${stamp}-${i}"
    i=$((i + 1))
  done

  mv "$dir" "$backup"
  echo "$backup"
}

# Rename an existing file to <name>.bak-<timestamp>. Echoes the backup path,
# or prints nothing if the source did not exist.
backup_file() {
  local file="$1"
  [[ ! -f "$file" ]] && return 0

  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  local backup="${file}.bak-${stamp}"
  local i=1
  while [[ -e "$backup" ]]; do
    backup="${file}.bak-${stamp}-${i}"
    i=$((i + 1))
  done

  mv "$file" "$backup"
  echo "$backup"
}

detect_collisions() {
  local target="$1"
  # Each branch must always exit 0 so 'set -e' doesn't terminate the caller
  # when the path simply doesn't exist (the common, expected case).
  case "$target" in
    cursor)          [[ -d "$TARGET_PATH/.cursor/rules" ]]  && echo '.cursor/rules/'  || true ;;
    claude-code)     [[ -d "$TARGET_PATH/.claude/agents" ]] && echo '.claude/agents/' || true ;;
    codex)
      if [[ "$SCOPE" == "user" ]]; then
        [[ -d "$HOME/.agents/skills" ]] && echo "$HOME/.agents/skills/" || true
      else
        local hits=()
        [[ -d "$TARGET_PATH/.agents/skills" ]] && hits+=('.agents/skills/')
        [[ -e "$TARGET_PATH/AGENTS.md" ]] && hits+=('AGENTS.md')
        if (( ${#hits[@]} > 0 )); then printf '%s ' "${hits[@]}"; fi
      fi
      ;;
    codex-agents-md) [[ -e "$TARGET_PATH/AGENTS.md" ]]      && echo 'AGENTS.md'        || true ;;
    openclaw)        [[ -d "$TARGET_PATH/skills" ]]          && echo 'skills/'          || true ;;
    raw)             [[ -d "$TARGET_PATH/docs/ai-rules" ]]  && echo 'docs/ai-rules/'  || true ;;
  esac
}

git_working_tree_state() {
  local dir="$1"
  # Use a subshell that always exits 0 so 'set -e' in the caller doesn't kill
  # the whole script when the directory isn't a git repo.
  local state
  state="$(
    set +e
    cd "$dir" 2>/dev/null || { echo 'not-a-repo'; exit 0; }
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo 'not-a-repo'; exit 0; }
    if [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then
      echo 'clean'
    else
      echo 'dirty'
    fi
  )"
  echo "$state"
}

# ---------------------------------------------------------------------------
# Installers
# ---------------------------------------------------------------------------

# Skills that should ship as Cursor `alwaysApply: true` rules: the meta layer
# (foundation rules that the pack is designed to inherit) plus the orchestrator
# router. Every other skill ships as `alwaysApply: false` and is reachable via
# `@<skill-name>` (Manual mode) or by Cursor's Agent Requested mode using the
# rule's description. Cursor does not read our generic `triggers:` field, so the
# only way these rules surface automatically is through these three Cursor-
# native frontmatter fields.
is_cursor_always_apply() {
  case "$1" in
    meta/engineering-principles|meta/reuse-before-create|meta/token-discipline|meta/task-router)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# Transform a generic SKILL.md into a Cursor-native .mdc rule.
#
# Cursor Project Rules require:
#   - .mdc extension (not .md, Cursor will not pick it up otherwise)
#   - Cursor-native frontmatter (description / globs / alwaysApply); our
#     `triggers:` and `applies_to:` are ignored by Cursor.
#   - description used by Cursor's Agent Requested mode to decide relevance.
#
# The body of the skill is preserved verbatim. Only the YAML frontmatter is
# rewritten.
write_cursor_mdc() {
  local src="$1"
  local dest="$2"
  local skill="$3"

  local always_apply="false"
  if is_cursor_always_apply "$skill"; then
    always_apply="true"
  fi

  # Pull description out of the source frontmatter. We keep the original
  # wording because it is hand-tuned for the agent's relevance decision.
  local description
  description=$(awk '
    /^---$/ { in_fm = !in_fm; next }
    in_fm && /^description:/ {
      sub(/^description: */, "")
      print
      exit
    }
  ' "$src")

  # Strip the existing frontmatter from the body (everything between the first
  # pair of --- lines plus the closing --- itself).
  local body
  body=$(awk '
    BEGIN { fm_count = 0 }
    /^---$/ { fm_count++; if (fm_count <= 2) next }
    fm_count >= 2 { print }
  ' "$src")

  # Write the Cursor-native rule.
  {
    echo "---"
    echo "description: $description"
    echo "globs:"
    echo "alwaysApply: $always_apply"
    echo "---"
    echo "$body"
  } > "$dest"
}

install_cursor() {
  local rules_dir="$TARGET_PATH/.cursor/rules"
  echo
  echo "Installing to $rules_dir"
  echo "  (Cursor target: writing .mdc Project Rules with Cursor-native frontmatter)"
  echo

  if (( DRY_RUN == 0 )); then mkdir -p "$rules_dir"; fi

  for skill in "${SKILLS[@]}"; do
    local name="${skill##*/}"
    local src="$PROMPTS_ROOT/$skill/SKILL.md"
    local dest="$rules_dir/$name.mdc"

    if [[ ! -f "$src" ]]; then echo "  Missing: $src" >&2; continue; fi

    if (( DRY_RUN == 1 )); then
      local mode="agent-requested"
      if is_cursor_always_apply "$skill"; then mode="always-apply"; fi
      echo "  [dry-run] would write $dest  ($mode)"
      continue
    fi

    handle_existing_file "$dest" || { echo "  Skipped."; continue; }
    write_cursor_mdc "$src" "$dest" "$skill"
    if is_cursor_always_apply "$skill"; then
      echo "  Wrote $dest  (alwaysApply: true)"
    else
      echo "  Wrote $dest  (agent-requested; invoke with @${name} for explicit use)"
    fi
  done

  # Also drop the bridge router so the agent learns the routing table without
  # needing to load every skill into context. The bridge is alwaysApply by
  # design - it is small and cheap, and it is what makes specialised rules
  # discoverable on Cursor where our generic triggers field is invisible.
  if (( DRY_RUN == 0 )); then
    write_cursor_bridge "$rules_dir/prompt-pack-router.mdc"
    echo "  Wrote $rules_dir/prompt-pack-router.mdc  (always-apply bridge)"
  else
    echo "  [dry-run] would write $rules_dir/prompt-pack-router.mdc  (always-apply bridge)"
  fi

  echo
  echo "Done. Reload your Cursor window to pick up the new rules."
  echo "Specialised rules are agent-requested; for critical workflows invoke them"
  echo "explicitly with @code-review, @security-review, @repo-audit, etc."
}

# The Cursor bridge router. Always-on, kept short by design. Maps the most
# common user intents - including Russian and Ukrainian - to the right
# skill, since Cursor cannot read our generic triggers field.
# Bridge content lives in templates/cursor-bridge.mdc as a single source of
# truth. Both install.sh and install.ps1 copy it byte-for-byte. PowerShell 5
# cannot safely embed Cyrillic literals in source files (it interprets them
# as ANSI/cp1252 unless the script has a UTF-8 BOM, which double-encodes the
# bytes); a separate file avoids the entire encoding pipeline.
write_cursor_bridge() {
  local dest="$1"
  local template="$SCRIPT_DIR/templates/cursor-bridge.mdc"
  if [[ ! -f "$template" ]]; then
    echo "  Warning: bridge template not found at $template; skipping bridge rule." >&2
    return
  fi
  cp "$template" "$dest"
}

install_claude_code() {
  local agents_dir="$TARGET_PATH/.claude/agents"
  echo
  echo "Installing to $agents_dir"
  echo

  if (( DRY_RUN == 0 )); then mkdir -p "$agents_dir"; fi

  for skill in "${SKILLS[@]}"; do
    local name="${skill##*/}"
    local src="$PROMPTS_ROOT/$skill/SKILL.md"
    local dest="$agents_dir/$name.md"

    if [[ ! -f "$src" ]]; then echo "  Missing: $src" >&2; continue; fi

    if (( DRY_RUN == 1 )); then
      echo "  [dry-run] would write $dest"
      continue
    fi

    handle_existing_file "$dest" || { echo "  Skipped."; continue; }
    cp "$src" "$dest"
    echo "  Wrote $dest"
  done

  echo
  echo "Done. Claude Code will pick up the agents on next start."
}

# Skills that exist as foundation rules. In Cursor we mark them alwaysApply;
# Codex has no inheritance, so we instead opt them out of implicit invocation
# (Codex still lists them, the user can call `$engineering-principles`
# explicitly, but the matcher won't auto-pick them on description match).
is_codex_inherit_only() {
  case "$1" in
    meta/engineering-principles|meta/reuse-before-create|meta/token-discipline|meta/task-router)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# Write a minimal agents/openai.yaml that disables implicit invocation for
# foundation skills. Schema: developers.openai.com/codex/skills.
write_codex_openai_yaml() {
  local dest_dir="$1"
  local agents_dir="$dest_dir/agents"
  mkdir -p "$agents_dir"
  cat > "$agents_dir/openai.yaml" <<'YAML'
# Disable implicit invocation: this skill is foundation/inherit-only.
# Codex will still list it; the user can call $<name> explicitly.
policy:
  allow_implicit_invocation: false
YAML
}

# Rewrite the source SKILL.md cross-skill links into a Codex-friendly form.
# In the repo, skills cross-reference each other with markdown links like
# `[`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md)`.
# Under the flat .agents/skills/ layout those relative paths don't resolve
# and the `meta/` category prefix in the label is misleading. Replace each
# such link with `$<basename>`, which is how Codex addresses skills.
#
# Examples:
#   [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md)
#       -> `$engineering-principles`
#   [`postgres-supabase`](../postgres-supabase/SKILL.md)
#       -> `$postgres-supabase`
#
# Implementation: extended-regex sed -E. The pattern matches the bracketed
# label, ignores the category prefix in it, and uses the URL's last segment
# (the basename before /SKILL.md) as the canonical skill name.
convert_cross_links_for_codex() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"
  # On BSD sed (macOS) and GNU sed (Linux), -E enables extended regex with
  # the same syntax used here. -i differs between BSD and GNU, so we write
  # to a temp file and move.
  sed -E 's/\[`[^`]+`\]\([^)]*\/([A-Za-z0-9._-]+)\/SKILL\.md\)/`$\1`/g' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# Codex-native install.
#
# Per the official Codex skills documentation
# (https://developers.openai.com/codex/skills), each skill is a directory
# with a SKILL.md file under one of the discovery roots:
#
#   - REPO:  <project>/.agents/skills/<name>/SKILL.md
#   - USER:  $HOME/.agents/skills/<name>/SKILL.md
#   - ADMIN: /etc/codex/skills/<name>/SKILL.md (we don't write here)
#
# Codex uses progressive disclosure: it reads only `name` and `description`
# from the frontmatter for the initial skill list (capped at ~2% of context
# or 8000 chars), and loads the full SKILL.md when the skill is selected.
#
# Our SKILL.md frontmatter already carries `name` + `description`, so we
# can copy each skill folder verbatim.
#
# We also write a compact AGENTS.md (~2 KB) at the repo root with the
# multilingual routing bridge so Codex picks the right skill when the user
# writes in Russian/Ukrainian. The full skill bodies stay in the skill
# folders; AGENTS.md only mentions skill names + intent aliases.
# Routing rules: each entry is "Label|skill1[,skill2]". The rule is emitted
# only if at least one target skill is in the installed set, and only the
# installed targets appear in the rendered line. This keeps AGENTS.md honest
# for any profile (minimal -> no `$code-review` rule, etc.) instead of
# pointing Codex at skills that aren't there.
CODEX_ROUTING_RULES=(
  "PR / diff review|code-review"
  "Repo-wide audit / no diff|repo-audit"
  "Security review|security-review"
  "Frontend feature or page|frontend-feature"
  "Frontend audit|frontend-audit"
  "Backend endpoint / API|backend-api"
  "DB schema / migrations|database-schema,database-migrations"
  "DB review|database-review"
  "Refactor request|refactor-planner"
  "Duplication audit|duplication-audit"
  "Bug investigation|debugger"
  "Test writing|test-writer"
  "Documentation|doc-writer"
  "UI design|ui-designer"
  "Handoff / wrap-up|handoff"
)

write_codex_agents_md() {
  local dest="$1"
  shift
  local skill_list=("$@")

  local template="$SCRIPT_DIR/templates/codex-agents-md.md"
  if [[ ! -f "$template" ]]; then
    echo "  Warning: AGENTS.md template not found at $template; skipping." >&2
    return 0
  fi

  # Build the set of installed skill basenames as an associative-style lookup.
  # bash 3.2 (macOS default) has no associative arrays, so we use a delimited
  # string and substring search.
  local installed_set="|"
  for skill in "${skill_list[@]}"; do
    installed_set+="${skill##*/}|"
  done

  # Render the "### Installed skills" bullet list.
  local skill_lines=""
  for skill in "${skill_list[@]}"; do
    local name="${skill##*/}"
    if [[ -n "$skill_lines" ]]; then
      skill_lines+=$'\n'
    fi
    skill_lines+="- \`\$${name}\`"
  done

  # First pass: pick rules whose at least one target is installed and find the
  # max label length so we can pad arrows for readability.
  local emitted_labels=()
  local emitted_targets=()
  local max_label=0
  for rule in "${CODEX_ROUTING_RULES[@]}"; do
    local label="${rule%%|*}"
    local targets_csv="${rule#*|}"
    local available_targets=""
    local targets_arr
    IFS=',' read -ra targets_arr <<< "$targets_csv"
    for t in "${targets_arr[@]}"; do
      if [[ "$installed_set" == *"|${t}|"* ]]; then
        if [[ -n "$available_targets" ]]; then
          available_targets+=" / "
        fi
        available_targets+="\`\$${t}\`"
      fi
    done
    if [[ -n "$available_targets" ]]; then
      emitted_labels+=("$label")
      emitted_targets+=("$available_targets")
      (( ${#label} > max_label )) && max_label=${#label}
    fi
  done

  # Second pass: render the routing block with right-padded labels.
  local routing_lines=""
  if (( ${#emitted_labels[@]} == 0 )); then
    routing_lines='_(No specialised skills installed; the agent will answer ad-hoc.)_'
  else
    local i
    for i in "${!emitted_labels[@]}"; do
      local label="${emitted_labels[$i]}"
      local pad=$(( max_label - ${#label} ))
      local spaces=""
      while (( pad > 0 )); do spaces+=" "; pad=$((pad - 1)); done
      if [[ -n "$routing_lines" ]]; then
        routing_lines+=$'\n'
      fi
      routing_lines+="- ${label}${spaces} -> ${emitted_targets[$i]}"
    done
  fi

  # Substitute placeholders by reading the template line-by-line. We avoided
  # awk -v / sed -e here because both choke on multi-line replacement values:
  # awk reports `newline in string` (replacement values contain literal \n),
  # and sed needs every / and & escaped in the replacement, plus the dollar
  # signs in `$<skill-name>` interact badly. Pure bash with parameter
  # expansion is portable from bash 3.2 (macOS default) onward and side-steps
  # the entire escaping problem.
  : > "$dest"
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      *'<!-- PROMPT_PACK_SKILL_LIST -->'*)
        printf '%s\n' "$skill_lines" >> "$dest"
        ;;
      *'<!-- PROMPT_PACK_ROUTING_RULES -->'*)
        printf '%s\n' "$routing_lines" >> "$dest"
        ;;
      *)
        printf '%s\n' "$line" >> "$dest"
        ;;
    esac
  done < "$template"
}

install_codex() {
  local skills_root
  local scope_label
  local write_agents_md=1

  if [[ "$SCOPE" == "user" ]]; then
    skills_root="$HOME/.agents/skills"
    scope_label="user (~/.agents/skills/)"
    write_agents_md=0
  else
    skills_root="$TARGET_PATH/.agents/skills"
    scope_label="repo (.agents/skills/)"
  fi

  echo
  echo "Installing Codex skills to $skills_root"
  echo "  (scope: $scope_label; format: Codex-native skill folders with progressive disclosure)"
  echo

  if (( DRY_RUN == 0 )); then mkdir -p "$skills_root"; fi

  for skill in "${SKILLS[@]}"; do
    local name="${skill##*/}"
    local src="$PROMPTS_ROOT/$skill"
    local dest="$skills_root/$name"

    if [[ ! -d "$src" ]]; then echo "  Missing: $src" >&2; continue; fi

    if (( DRY_RUN == 1 )); then
      local action='create'
      [[ -d "$dest" ]] && action='replace (existing renamed to .bak)'
      echo "  [dry-run] would $action $dest"
      continue
    fi

    if [[ -d "$dest" ]]; then
      if (( FORCE == 0 )); then
        read -r -p "  Replace $dest? Existing will be renamed to <name>.bak-<timestamp>. [y/N] " resp
        [[ "$resp" =~ ^[yY]$ ]] || { echo "  Skipped."; continue; }
      fi
      local backup
      backup="$(backup_directory "$dest")"
      [[ -n "$backup" ]] && echo "  Backed up to $backup"
    fi

    cp -R "$src" "$dest"

    # Rewrite cross-skill links inside the copied SKILL.md so they refer
    # to Codex skill names ($foo) instead of relative ../meta/foo/SKILL.md
    # paths that don't exist under the flat .agents/skills/ layout.
    local skill_file="$dest/SKILL.md"
    if [[ -f "$skill_file" ]]; then
      convert_cross_links_for_codex "$skill_file"
    fi

    # Mark foundation skills as explicit-only so Codex doesn't auto-select
    # them based on description match.
    if is_codex_inherit_only "$skill"; then
      write_codex_openai_yaml "$dest"
      echo "  Wrote $dest  (skill: $name, explicit-only)"
    else
      echo "  Wrote $dest  (skill: $name)"
    fi
  done

  if (( write_agents_md == 1 )); then
    local agents_file="$TARGET_PATH/AGENTS.md"
    if (( DRY_RUN == 1 )); then
      local verb='create'
      [[ -e "$agents_file" ]] && verb='replace'
      echo
      echo "  [dry-run] would $verb $agents_file (compact router bridge)"
    else
      local write_bridge=1
      if [[ -e "$agents_file" ]]; then
        if (( FORCE == 0 )); then
          read -r -p $'\n'"$agents_file exists. Overwrite with prompt-pack router bridge? [y/N] " resp
          if [[ ! "$resp" =~ ^[yY]$ ]]; then
            echo "  Skipped AGENTS.md."
            write_bridge=0
          fi
        else
          local backup
          backup="$(backup_file "$agents_file")"
          [[ -n "$backup" ]] && echo "  Backed up existing AGENTS.md to $backup"
        fi
      fi
      if (( write_bridge == 1 )); then
        write_codex_agents_md "$agents_file" "${SKILLS[@]}"
        echo "  Wrote $agents_file  (compact router bridge)"
      fi
    fi
  fi

  echo
  echo "Done. Restart Codex to pick up the new skills."
  echo "Skills are activated via \$<skill-name> (explicit) or by Codex matching the description (implicit)."
  if [[ "$SCOPE" == "user" ]]; then
    echo "User-scoped skills apply to every Codex session, regardless of working directory."
  else
    echo "Repo-scoped skills apply when Codex is launched inside this project."
  fi
}

# Legacy single-file Codex install. Concatenates all skills into one
# AGENTS.md, capped at 32 KiB. Kept for hosts that do not yet support
# `.agents/skills/` (or for users who explicitly want one big project doc).
# Prefer `--target codex` for everything else.
install_codex_agents_md() {
  local agents_file="$TARGET_PATH/AGENTS.md"
  local size_limit=$((32 * 1024))
  echo
  echo "Building $agents_file from ${#SKILLS[@]} skills (legacy single-file mode)"
  echo

  if (( DRY_RUN == 1 )); then
    local verb='create'
    [[ -e "$agents_file" ]] && verb='replace'
    echo "  [dry-run] would $verb $agents_file from ${#SKILLS[@]} skills"
    return 0
  fi

  if [[ -e "$agents_file" ]]; then
    if (( FORCE == 0 )); then
      read -r -p "$agents_file exists. Overwrite? [y/N] " resp
      [[ "$resp" =~ ^[yY]$ ]] || { echo "Aborted."; return 1; }
    else
      local backup
      backup="$(backup_file "$agents_file")"
      [[ -n "$backup" ]] && echo "Backed up existing AGENTS.md to $backup"
    fi
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
    # Strip relative cross-skill links (e.g. [meta/foo](../foo/SKILL.md)) that are
    # valid source cross-references but become broken paths once all skills are
    # inlined into a single AGENTS.md. The referenced skill is already present as
    # a separate section in the same file.
    body="$(printf '%s' "$body" | sed 's/\[\([^]]*\)\](\.\.\/[^)]*\/SKILL\.md)/\1/g')"
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
    echo "Tip: switch to '--target codex' (Codex-native, progressive disclosure) instead of dumping everything into one AGENTS.md."
  fi
}

install_openclaw() {
  local skills_dir="$TARGET_PATH/skills"
  echo
  echo "Installing skill directories to $skills_dir"
  echo

  if (( DRY_RUN == 0 )); then mkdir -p "$skills_dir"; fi

  for skill in "${SKILLS[@]}"; do
    local name="${skill##*/}"
    local src="$PROMPTS_ROOT/$skill"
    local dest="$skills_dir/$name"

    if [[ ! -d "$src" ]]; then echo "  Missing: $src" >&2; continue; fi

    if (( DRY_RUN == 1 )); then
      local action='create'
      [[ -d "$dest" ]] && action='replace (existing renamed to .bak)'
      echo "  [dry-run] would $action $dest"
      continue
    fi

    if [[ -d "$dest" ]]; then
      if (( FORCE == 0 )); then
        read -r -p "  Replace $dest? Existing will be renamed to <name>.bak-<timestamp>. [y/N] " resp
        [[ "$resp" =~ ^[yY]$ ]] || { echo "  Skipped."; continue; }
      fi
      local backup
      backup="$(backup_directory "$dest")"
      [[ -n "$backup" ]] && echo "  Backed up to $backup"
    fi

    cp -R "$src" "$dest"
    echo "  Wrote $dest"
  done

  echo
  echo "Done."
  echo "Backups (if any) are in $skills_dir as <name>.bak-<timestamp> directories."
  echo "Delete them when you're confident the new version works."
}

install_raw() {
  local raw_dir="$TARGET_PATH/docs/ai-rules"
  echo
  echo "Installing raw markdown bodies to $raw_dir"
  echo

  if (( DRY_RUN == 0 )); then mkdir -p "$raw_dir"; fi

  for skill in "${SKILLS[@]}"; do
    local name="${skill##*/}"
    local src="$PROMPTS_ROOT/$skill/SKILL.md"
    local dest="$raw_dir/$name.md"

    if [[ ! -f "$src" ]]; then echo "  Missing: $src" >&2; continue; fi

    if (( DRY_RUN == 1 )); then
      echo "  [dry-run] would write $dest"
      continue
    fi

    handle_existing_file "$dest" || { echo "  Skipped."; continue; }
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
    --scope)    SCOPE="$2"; shift 2 ;;
    --skill)    EXPLICIT_SKILLS+=("$2"); shift 2 ;;
    --force)    FORCE=1; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
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
  echo "Error: --target is required (cursor / claude-code / codex / codex-agents-md / openclaw / raw)." >&2
  echo "Run with --list to see available profiles and skills." >&2
  exit 1
fi

case "$TARGET" in
  cursor|claude-code|codex|codex-agents-md|openclaw|raw) ;;
  *) echo "Error: invalid --target '$TARGET'" >&2; exit 1 ;;
esac

case "$SCOPE" in
  repo|user) ;;
  *) echo "Error: invalid --scope '$SCOPE' (expected: repo, user)" >&2; exit 1 ;;
esac

TARGET_PATH="$(cd "$TARGET_PATH" 2>/dev/null && pwd || { echo "Error: path does not exist: $TARGET_PATH" >&2; exit 1; })"

if (( ${#EXPLICIT_SKILLS[@]} > 0 )); then
  SKILLS=("${EXPLICIT_SKILLS[@]}")
else
  # bash 3.2 compatibility (macOS default bash): use read loop instead of mapfile.
  # mapfile is bash 4+ only; macOS still ships bash 3.2 because of the GPLv3 switch,
  # so any script that wants to run on a stock Mac shell must avoid it.
  SKILLS=()
  while IFS= read -r _line; do
    SKILLS+=("$_line")
  done < <(profile_skills "$PROFILE")
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
(( DRY_RUN == 1 )) && echo "Mode:    dry-run (no changes will be made)"
(( FORCE   == 1 )) && echo "Mode:    force (existing files replaced; directories backed up to .bak-<timestamp>)"

# Pre-flight warnings
collision="$(detect_collisions "$TARGET")"
if [[ -n "$collision" ]]; then
  echo
  echo "Notice: agent-config already present at: $collision"
  echo "This run will modify or replace it. Use --dry-run first if unsure."
fi

git_state="$(git_working_tree_state "$TARGET_PATH")"
if [[ "$git_state" == 'dirty' ]]; then
  echo
  echo "Notice: git working tree is dirty. Consider committing or stashing before installing"
  echo "so you can review changes via 'git diff' afterwards."
elif [[ "$git_state" == 'not-a-repo' ]]; then
  echo
  echo "Notice: this directory isn't a git repository. Without git, undoing a bad install"
  echo "requires manual deletion of the files this script writes."
fi

case "$TARGET" in
  cursor)          install_cursor ;;
  claude-code)     install_claude_code ;;
  codex)           install_codex ;;
  codex-agents-md) install_codex_agents_md ;;
  openclaw)        install_openclaw ;;
  raw)             install_raw ;;
esac
