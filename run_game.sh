#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

GODOT_PATH="${GODOT_EXE:-}"
EDITOR=0
PROJECT_MANAGER=0
PRINT_COMMAND=0
EXTRA_ARGS=()

usage() {
  cat <<'EOF'
Usage:
  ./run_game.sh [options] [-- extra godot args]

Options:
  --godot-path PATH     Path to Godot executable
  --editor              Open the Godot editor for this project
  --project-manager     Open Godot project manager
  --print-command       Print the command before running
  -h, --help            Show this help

Examples:
  ./run_game.sh
  ./run_game.sh --editor
  ./run_game.sh --godot-path "/c/Tools/Godot/Godot_v4.x-stable_win64.exe"
  GODOT_EXE="/c/Tools/Godot/Godot_v4.x-stable_win64.exe" ./run_game.sh
EOF
}

to_unix_path() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$path" 2>/dev/null || printf '%s\n' "$path"
  else
    printf '%s\n' "$path"
  fi
}

to_windows_path() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$path" 2>/dev/null || printf '%s\n' "$path"
  else
    printf '%s\n' "$path"
  fi
}

resolve_godot() {
  if [[ -n "$GODOT_PATH" ]]; then
    local explicit
    explicit="$(to_unix_path "$GODOT_PATH")"
    if [[ -f "$explicit" ]]; then
      printf '%s\n' "$explicit"
      return 0
    fi
    if [[ -d "$explicit" ]]; then
      local nested
      shopt -s nullglob
      for nested in "$explicit"/Godot*.exe; do
        if [[ -f "$nested" && "$nested" != *console* ]]; then
          printf '%s\n' "$nested"
          shopt -u nullglob
          return 0
        fi
      done
      for nested in "$explicit"/Godot*.exe; do
        if [[ -f "$nested" ]]; then
          printf '%s\n' "$nested"
          shopt -u nullglob
          return 0
        fi
      done
      shopt -u nullglob
    fi
    printf 'Godot executable not found at: %s\n' "$GODOT_PATH" >&2
    return 1
  fi

  local project_godot
  shopt -s nullglob
  for project_godot in "$PROJECT_ROOT"/Godot*.exe; do
    if [[ -f "$project_godot" && "$project_godot" != *console* ]]; then
      printf '%s\n' "$project_godot"
      shopt -u nullglob
      return 0
    fi
  done
  for project_godot in "$PROJECT_ROOT"/Godot*.exe/Godot*.exe; do
    if [[ -f "$project_godot" && "$project_godot" != *console* ]]; then
      printf '%s\n' "$project_godot"
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob

  local command_name
  for command_name in godot godot4 godot.exe godot4.exe; do
    if command -v "$command_name" >/dev/null 2>&1; then
      command -v "$command_name"
      return 0
    fi
  done

  local candidates=(
    "/c/Program Files/Godot/Godot.exe"
    "/c/Program Files/Godot/Godot_v4.exe"
    "/c/Program Files/Godot/Godot_v4.2-stable_win64.exe"
    "/c/Program Files/Godot/Godot_v4.3-stable_win64.exe"
    "/c/Program Files/Godot/Godot_v4.4-stable_win64.exe"
    "/c/Program Files/Godot/Godot_v4.5-stable_win64.exe"
    "$HOME/scoop/shims/godot.exe"
    "$HOME/scoop/apps/godot/current/godot.exe"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  cat >&2 <<'EOF'
Could not find Godot.

Install Godot 4.x, then use one of these in Git Bash:

  winget install -e --id GodotEngine.GodotEngine

Then open a new Git Bash and run:

  ./run_game.sh

If you already have Godot downloaded somewhere:

  ./run_game.sh --godot-path "/c/Path/To/Godot_v4.x-stable_win64.exe"

Or set GODOT_EXE:

  export GODOT_EXE="/c/Path/To/Godot_v4.x-stable_win64.exe"
  ./run_game.sh

Or add Godot to PATH so `godot --version` works.
EOF
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot-path)
      GODOT_PATH="${2:-}"
      if [[ -z "$GODOT_PATH" ]]; then
        printf '--godot-path requires a value.\n' >&2
        exit 1
      fi
      shift 2
      ;;
    --editor)
      EDITOR=1
      shift
      ;;
    --project-manager)
      PROJECT_MANAGER=1
      shift
      ;;
    --print-command)
      PRINT_COMMAND=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

GODOT="$(resolve_godot)"
PROJECT_PATH="$(to_windows_path "$PROJECT_ROOT")"

ARGS=()
if [[ "$PROJECT_MANAGER" -eq 1 ]]; then
  ARGS+=(--project-manager)
else
  ARGS+=(--path "$PROJECT_PATH")
  if [[ "$EDITOR" -eq 1 ]]; then
    ARGS+=(--editor)
  fi
fi

if [[ "${#EXTRA_ARGS[@]}" -gt 0 ]]; then
  ARGS+=("${EXTRA_ARGS[@]}")
fi

printf 'Godot:  %s\n' "$GODOT"
if [[ "$PROJECT_MANAGER" -ne 1 ]]; then
  printf 'Project: %s\n' "$PROJECT_PATH"
fi

if [[ "$PRINT_COMMAND" -eq 1 ]]; then
  printf 'Command: %q' "$GODOT"
  printf ' %q' "${ARGS[@]}"
  printf '\n'
fi

"$GODOT" "${ARGS[@]}"
