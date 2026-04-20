#!/bin/bash
# SessionEnd hook: weekly /mb compact reminder.
#
# Trigger: после ручного `/mb compact --apply` создаётся .memory-bank/.last-compact.
# Если с тех пор прошло >7 дней И mb-compact.sh --dry-run показывает candidates > 0 →
# этот hook выводит reminder на stderr.
#
# Opt-in by design:
#   - Нет .memory-bank/.last-compact → silent (пользователь ни разу не вызвал compact)
#   - MB_COMPACT_REMIND=off → полный noop (env opt-out)
#   - Read-only: не создаёт/не меняет файлов

set -u

command -v jq >/dev/null 2>&1 || exit 0   # без jq — тихо noop

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -z "$CWD" ] && CWD="$PWD"

MB="$CWD/.memory-bank"
[ -d "$MB" ] || exit 0

MODE="${MB_COMPACT_REMIND:-auto}"
[ "$MODE" = "off" ] && exit 0

LAST="$MB/.last-compact"
# Opt-in: если .last-compact не существует, молчим (пользователь не подписан на feature)
[ -f "$LAST" ] || exit 0

# Portable mtime
mtime() {
  stat -f%m "$1" 2>/dev/null || stat -c%Y "$1" 2>/dev/null || echo 0
}

now=$(date +%s)
age=$(( now - $(mtime "$LAST") ))
WEEK=$((7 * 24 * 3600))

# Свежий .last-compact → silent
[ "$age" -lt "$WEEK" ] && exit 0

# Stale → запускаем dry-run, парсим candidates
COMPACT_SCRIPT="$HOME/.claude/skills/memory-bank/scripts/mb-compact.sh"
# Fallback для in-repo тестов: скрипт рядом с нами (../scripts/)
if [ ! -x "$COMPACT_SCRIPT" ]; then
  HOOK_DIR=$(cd "$(dirname "$0")" && pwd)
  REPO_COMPACT="$HOOK_DIR/../scripts/mb-compact.sh"
  [ -x "$REPO_COMPACT" ] && COMPACT_SCRIPT="$REPO_COMPACT"
fi

[ -x "$COMPACT_SCRIPT" ] || exit 0   # скрипт недоступен — silent skip

# Запускаем dry-run в CWD, парсим candidates=N
OUTPUT=$(cd "$CWD" && bash "$COMPACT_SCRIPT" --dry-run 2>/dev/null || true)
CANDIDATES=$(printf '%s\n' "$OUTPUT" | grep -E '^candidates=' | head -1 | cut -d= -f2)
CANDIDATES="${CANDIDATES:-0}"

# 0 кандидатов — silent
[ "$CANDIDATES" = "0" ] && exit 0

# Есть что сжимать → reminder в stderr
age_days=$(( age / 86400 ))
{
  echo ""
  echo "[memory-bank] Compaction reminder:"
  echo "  ${CANDIDATES} candidate(s) ready for /mb compact (last compact: ${age_days}d ago)"
  echo "  Run: /mb compact --dry-run  (or /mb compact --apply to archive)"
  echo "  Silence: export MB_COMPACT_REMIND=off"
} >&2

exit 0
