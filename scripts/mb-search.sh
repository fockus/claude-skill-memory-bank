#!/usr/bin/env bash
# mb-search.sh — поиск по Memory Bank.
#
# Usage:
#   mb-search.sh <query> [mb_path]          # полнотекстовый grep/rg
#   mb-search.sh --tag <tag> [mb_path]      # фильтр по tag из index.json
#
# Флаг --tag требует .memory-bank/index.json (генерируется mb-index-json.py).
# Если index.json отсутствует — warning + auto-regenerate попытка, иначе exit 1.

set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

if [ "${1:-}" = "--tag" ]; then
  TAG="${2:?Usage: mb-search.sh --tag <tag> [mb_path]}"
  MB_PATH=$(mb_resolve_path "${3:-}")

  INDEX="$MB_PATH/index.json"
  if [ ! -f "$INDEX" ]; then
    # Попытаться сгенерировать
    if [ -x "$(dirname "$0")/mb-index-json.py" ]; then
      python3 "$(dirname "$0")/mb-index-json.py" "$MB_PATH" >/dev/null 2>&1 || true
    fi
  fi

  if [ ! -f "$INDEX" ]; then
    echo "[error] index.json не найден: $INDEX" >&2
    echo "[hint]  сгенерируй: python3 $(dirname "$0")/mb-index-json.py $MB_PATH" >&2
    exit 1
  fi

  # Извлечь paths where tag matches. Portable через python3 (jq опционален).
  matches=$(TAG="$TAG" INDEX_PATH="$INDEX" python3 -c "
import json, os
tag = os.environ['TAG']
with open(os.environ['INDEX_PATH']) as f: data = json.load(f)
for n in data.get('notes', []):
    if tag in (n.get('tags') or []):
        print(n['path'])
")

  if [ -z "$matches" ]; then
    echo "Ничего не найдено по тегу: $TAG"
    exit 0
  fi

  echo "$matches" | while read -r rel; do
    [ -z "$rel" ] && continue
    echo "=== $rel ==="
    head -20 "$MB_PATH/$rel" 2>/dev/null || true
    echo ""
  done
  exit 0
fi

QUERY="${1:?Usage: mb-search.sh <query> [mb_path]  OR  mb-search.sh --tag <tag> [mb_path]}"
MB_PATH=$(mb_resolve_path "${2:-}")

if [[ ! -d "$MB_PATH" ]]; then
  echo "[MEMORY BANK: INACTIVE] Директория $MB_PATH не найдена" >&2
  exit 1
fi

# ripgrep с fallback на grep
if command -v rg >/dev/null 2>&1; then
  rg --color=never -n -i --type md --heading "$QUERY" "$MB_PATH" || echo "Ничего не найдено по запросу: $QUERY"
else
  grep -rn -i --include="*.md" "$QUERY" "$MB_PATH" || echo "Ничего не найдено по запросу: $QUERY"
fi
