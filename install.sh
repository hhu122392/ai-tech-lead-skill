#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$ROOT/ai-tech-lead"
SCOPE="user"
TARGET="both"
PROJECT_PATH="$PWD"
INSTALL_AGENTS=0
FORCE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --scope user|project        Installation scope (default: user)
  --target codex|claude|both Target client (default: both)
  --project PATH              Project path for project scope
  --agents                    Install optional custom agent profiles
  --force                     Replace existing files
  --dry-run                  Show changes without writing files
  -h, --help                  Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --project) PROJECT_PATH="$2"; shift 2 ;;
    --agents) INSTALL_AGENTS=1; shift ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

[[ "$SCOPE" == "user" || "$SCOPE" == "project" ]] || { echo "Invalid --scope" >&2; exit 2; }
[[ "$TARGET" == "codex" || "$TARGET" == "claude" || "$TARGET" == "both" ]] || { echo "Invalid --target" >&2; exit 2; }
[[ -f "$SKILL_SOURCE/SKILL.md" ]] || { echo "Skill source not found: $SKILL_SOURCE" >&2; exit 1; }

copy_dir() {
  local src="$1"
  local dest="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Would install: $dest"
    return
  fi
  local stage="${dest}.stage.$$"
  local backup=""
  if [[ -e "$dest" ]]; then
    if [[ "$FORCE" -ne 1 ]]; then
      echo "Destination exists: $dest. Re-run with --force." >&2
      exit 1
    fi
    backup="${dest}.backup.$(date +%Y%m%d%H%M%S%N)"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$stage"
  if [[ -n "$backup" ]]; then
    mv "$dest" "$backup"
  fi
  if ! mv "$stage" "$dest"; then
    rm -rf "$stage"
    if [[ -n "$backup" && -e "$backup" && ! -e "$dest" ]]; then
      mv "$backup" "$dest"
    fi
    echo "Install failed; previous version restored: $dest" >&2
    exit 1
  fi
  echo "Installed: $dest"
  if [[ -n "$backup" ]]; then
    echo "Previous version backed up: $backup"
  fi
}

copy_agents() {
  local src="$1"
  local dest="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Would install agent profiles: $dest"
    return
  fi
  mkdir -p "$dest"
  shopt -s nullglob
  local files=("$src"/*)
  local collisions=()
  for file in "${files[@]}"; do
    local target="$dest/$(basename "$file")"
    [[ -e "$target" && "$FORCE" -ne 1 ]] && collisions+=("$target")
  done
  if [[ "${#collisions[@]}" -gt 0 ]]; then
    echo "Agent profiles already exist: ${collisions[*]}. Re-run with --force." >&2
    exit 1
  fi
  local stage="${dest}.stage.$$"
  local backup=""
  local moved=()
  local copied=()
  mkdir -p "$stage"
  for file in "${files[@]}"; do
    local target="$dest/$(basename "$file")"
    if ! cp "$file" "$stage/$(basename "$file")"; then
      rm -rf "$stage"
      echo "Agent profile staging failed; no files were changed: $dest" >&2
      exit 1
    fi
  done
  if [[ "$FORCE" -eq 1 ]]; then
    for file in "${files[@]}"; do
      local target="$dest/$(basename "$file")"
      if [[ -e "$target" ]]; then
        [[ -z "$backup" ]] && backup="${dest}.backup.$(date +%Y%m%d%H%M%S%N)" && mkdir -p "$backup"
        mv "$target" "$backup/$(basename "$file")"
        moved+=("$target")
      fi
    done
  fi
  for file in "$stage"/*; do
    local target="$dest/$(basename "$file")"
    if ! mv "$file" "$target"; then
      for item in "${copied[@]}"; do rm -f "$item"; done
      for item in "${moved[@]}"; do
        local backup_file="$backup/$(basename "$item")"
        [[ -e "$backup_file" ]] && mv "$backup_file" "$item"
      done
      rm -rf "$stage"
      echo "Agent profile install failed; previous version restored: $dest" >&2
      exit 1
    fi
    copied+=("$target")
    echo "Installed agent profile: $target"
  done
  rm -rf "$stage"
  if [[ -n "$backup" ]]; then
    echo "Previous agent profiles backed up: $backup"
  fi
}

check_agent_destination_free() {
  local src="$1"
  local dest="$2"
  shopt -s nullglob
  local collisions=()
  for file in "$src"/*; do
    local target="$dest/$(basename "$file")"
    [[ -e "$target" ]] && collisions+=("$target")
  done
  if [[ "${#collisions[@]}" -gt 0 ]]; then
    echo "Preflight failed; existing agent profiles: ${collisions[*]}. No files were changed." >&2
    exit 1
  fi
}

if [[ "$SCOPE" == "project" ]]; then
  PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
fi

install_codex=0
install_claude=0
[[ "$TARGET" == "codex" || "$TARGET" == "both" ]] && install_codex=1
[[ "$TARGET" == "claude" || "$TARGET" == "both" ]] && install_claude=1

skill_destinations=()
if [[ "$SCOPE" == "user" ]]; then
  [[ "$install_codex" -eq 1 ]] && skill_destinations+=("$HOME/.codex/skills/ai-tech-lead")
  [[ "$install_claude" -eq 1 ]] && skill_destinations+=("$HOME/.claude/skills/ai-tech-lead")
else
  [[ "$install_codex" -eq 1 ]] && skill_destinations+=("$PROJECT_PATH/.codex/skills/ai-tech-lead")
  [[ "$install_claude" -eq 1 ]] && skill_destinations+=("$PROJECT_PATH/.claude/skills/ai-tech-lead")
fi

if [[ "$FORCE" -ne 1 && "$DRY_RUN" -ne 1 ]]; then
  existing=()
  for dest in "${skill_destinations[@]}"; do
    [[ -e "$dest" ]] && existing+=("$dest")
  done
  if [[ "${#existing[@]}" -gt 0 ]]; then
    echo "Preflight failed; existing skill destinations: ${existing[*]}. No files were changed." >&2
    exit 1
  fi
  if [[ "$INSTALL_AGENTS" -eq 1 ]]; then
    if [[ "$SCOPE" == "user" ]]; then
      [[ "$install_codex" -eq 1 ]] && check_agent_destination_free "$ROOT/integrations/codex/agents" "$HOME/.codex/agents"
      [[ "$install_claude" -eq 1 ]] && check_agent_destination_free "$ROOT/integrations/claude-code/agents" "$HOME/.claude/agents"
    else
      [[ "$install_codex" -eq 1 ]] && check_agent_destination_free "$ROOT/integrations/codex/agents" "$PROJECT_PATH/.codex/agents"
      [[ "$install_claude" -eq 1 ]] && check_agent_destination_free "$ROOT/integrations/claude-code/agents" "$PROJECT_PATH/.claude/agents"
    fi
  fi
fi

if [[ "$SCOPE" == "user" ]]; then
  if [[ "$install_codex" -eq 1 ]]; then
    copy_dir "$SKILL_SOURCE" "$HOME/.codex/skills/ai-tech-lead"
    [[ "$INSTALL_AGENTS" -eq 1 ]] && copy_agents "$ROOT/integrations/codex/agents" "$HOME/.codex/agents"
  fi
  if [[ "$install_claude" -eq 1 ]]; then
    copy_dir "$SKILL_SOURCE" "$HOME/.claude/skills/ai-tech-lead"
    [[ "$INSTALL_AGENTS" -eq 1 ]] && copy_agents "$ROOT/integrations/claude-code/agents" "$HOME/.claude/agents"
  fi
else
  if [[ "$install_codex" -eq 1 ]]; then
    copy_dir "$SKILL_SOURCE" "$PROJECT_PATH/.codex/skills/ai-tech-lead"
    [[ "$INSTALL_AGENTS" -eq 1 ]] && copy_agents "$ROOT/integrations/codex/agents" "$PROJECT_PATH/.codex/agents"
  fi
  if [[ "$install_claude" -eq 1 ]]; then
    copy_dir "$SKILL_SOURCE" "$PROJECT_PATH/.claude/skills/ai-tech-lead"
    [[ "$INSTALL_AGENTS" -eq 1 ]] && copy_agents "$ROOT/integrations/claude-code/agents" "$PROJECT_PATH/.claude/agents"
  fi
fi

echo
echo "Installation complete. Restart the client if the skill is not visible."
echo 'Use $ai-tech-lead in Codex or /ai-tech-lead in Claude Code.'
