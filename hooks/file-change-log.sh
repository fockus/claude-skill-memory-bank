#!/bin/bash
# PostToolUse hook: логирование изменений файлов (Write/Edit)
# Записывает в ~/.claude/file-changes.log

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required for hook" >&2; exit 1; }

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="$HOME/.claude/file-changes.log"

# Определи тип операции
case "$TOOL" in
  Write)
    echo "[$TIMESTAMP] WRITE: $FILE_PATH" >> "$LOG_FILE"
    ;;
  Edit)
    echo "[$TIMESTAMP] EDIT: $FILE_PATH" >> "$LOG_FILE"
    ;;
esac

# Проверки после записи
if [ -f "$FILE_PATH" ]; then
  # Проверка на placeholder'ы в коде (не в .md файлах)
  if [[ ! "$FILE_PATH" =~ \.(md|txt|json|yaml|yml|toml|cfg|ini|env)$ ]]; then
    PLACEHOLDERS=$(grep -nE '(TODO|FIXME|HACK|XXX|PLACEHOLDER|NotImplementedError|raise NotImplemented|pass\s*$)' "$FILE_PATH" 2>/dev/null | head -5)
    if [ -n "$PLACEHOLDERS" ]; then
      echo "WARNING: Placeholder'ы найдены в $FILE_PATH:" >&2
      echo "$PLACEHOLDERS" >&2
    fi
  fi

  # Проверка на случайное коммит secrets
  if [[ "$FILE_PATH" =~ \.(py|go|js|ts|rb|java|rs|swift|kt)$ ]]; then
    SECRETS=$(grep -nEi '(password|secret|api_key|token|private_key)\s*=\s*["\x27][^"\x27]{8,}' "$FILE_PATH" 2>/dev/null | grep -vEi '(test|mock|fake|example|placeholder|xxx|your_)' | head -3)
    if [ -n "$SECRETS" ]; then
      echo "WARNING: Possible hardcoded secrets in $FILE_PATH:" >&2
      echo "$SECRETS" >&2
    fi
  fi
fi

exit 0
