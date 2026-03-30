#!/usr/bin/env bash
# mb-note.sh — создание заметки в Memory Bank
# Usage: mb-note.sh <topic> [mb_path]
# Создаёт notes/YYYY-MM-DD_HH-MM_<topic>.md с шаблоном

set -euo pipefail

TOPIC="${1:?Usage: mb-note.sh <topic> [mb_path]}"

# Auto-resolve from .claude-workspace if no explicit path given
if [[ -z "${2:-}" ]] && [[ -f ".claude-workspace" ]]; then
  _WS_STORAGE=$(grep "^storage:" .claude-workspace 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "local")
  if [[ "$_WS_STORAGE" == "external" ]]; then
    _WS_PROJECT_ID=$(grep "^project_id:" .claude-workspace 2>/dev/null | awk '{print $2}' | tr -d '"')
    MB_PATH="$HOME/.claude/workspaces/$_WS_PROJECT_ID/.memory-bank"
  else
    MB_PATH=".memory-bank"
  fi
else
  MB_PATH="${2:-.memory-bank}"
fi
NOTES_DIR="$MB_PATH/notes"

# Sanitize topic: lowercase, replace spaces with dashes, strip non-alphanumeric
SAFE_TOPIC=$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
FILENAME="${TIMESTAMP}_${SAFE_TOPIC}.md"
FILEPATH="$NOTES_DIR/$FILENAME"

mkdir -p "$NOTES_DIR"

if [[ -f "$FILEPATH" ]]; then
  echo "Файл уже существует: $FILEPATH" >&2
  exit 1
fi

DATE_NOW=$(date +"%Y-%m-%d %H:%M")
printf '# %s\nDate: %s\n' "$TOPIC" "$DATE_NOW" > "$FILEPATH"
cat >> "$FILEPATH" << 'EOF'

## Что сделано
-

## Новые знания
-
EOF

echo "$FILEPATH"
