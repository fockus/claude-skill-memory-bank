#!/usr/bin/env bash
# mb-context.sh — собирает текущий контекст из Memory Bank
# Usage: mb-context.sh [mb_path]
# Default path: .memory-bank/

set -euo pipefail

# Auto-resolve from .claude-workspace if no explicit path given
if [[ -z "${1:-}" ]] && [[ -f ".claude-workspace" ]]; then
  _WS_STORAGE=$(grep "^storage:" .claude-workspace 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "local")
  if [[ "$_WS_STORAGE" == "external" ]]; then
    _WS_PROJECT_ID=$(grep "^project_id:" .claude-workspace 2>/dev/null | awk '{print $2}' | tr -d '"')
    MB_PATH="$HOME/.claude/workspaces/$_WS_PROJECT_ID/.memory-bank"
  else
    MB_PATH=".memory-bank"
  fi
else
  MB_PATH="${1:-.memory-bank}"
fi

if [[ ! -d "$MB_PATH" ]]; then
  echo "[MEMORY BANK: INACTIVE] Директория $MB_PATH не найдена"
  exit 0
fi

echo "=== [MEMORY BANK: ACTIVE] ==="
echo ""

# Core files
for file in STATUS.md plan.md checklist.md RESEARCH.md; do
  filepath="$MB_PATH/$file"
  if [[ -f "$filepath" ]]; then
    echo "--- $file ---"
    cat "$filepath"
    echo ""
  fi
done

# Активные планы (не в done/)
if [[ -d "$MB_PATH/plans" ]]; then
  active_plans=$(find "$MB_PATH/plans" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort -r | head -3)
  if [[ -n "$active_plans" ]]; then
    echo "--- Активные планы ---"
    while IFS= read -r plan; do
      echo "  - $(basename "$plan")"
    done <<< "$active_plans"
    echo ""
  fi
fi

# Последняя заметка
if [[ -d "$MB_PATH/notes" ]]; then
  latest_note=$(find "$MB_PATH/notes" -name "*.md" -type f 2>/dev/null | sort -r | head -1)
  if [[ -n "$latest_note" ]]; then
    echo "--- Последняя заметка: $(basename "$latest_note") ---"
    cat "$latest_note"
    echo ""
  fi
fi
