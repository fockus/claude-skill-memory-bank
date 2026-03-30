#!/usr/bin/env bash
# mb-search.sh — поиск по Memory Bank
# Usage: mb-search.sh <query> [mb_path]

set -euo pipefail

QUERY="${1:?Usage: mb-search.sh <query> [mb_path]}"

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
