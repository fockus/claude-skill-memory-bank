#!/usr/bin/env bash
# mb-plan-sync.sh — синхронизирует план с checklist.md + plan.md.
#
# Usage:
#   mb-plan-sync.sh <plan-file> [mb_path]
#
# Эффекты:
#   - Из плана извлекаются пары (N, name) через маркеры `<!-- mb-stage:N -->`
#     (fallback: regex `### Этап N: <name>`).
#   - В checklist.md для каждой пары, если секция `## Этап N: <name>`
#     отсутствует — добавляется в конец файла вместе с одним пунктом `- ⬜ <name>`.
#     Существующие секции не модифицируются → идемпотентно.
#   - В plan.md блок между маркерами `<!-- mb-active-plan -->` и
#     `<!-- /mb-active-plan -->` заменяется на единственную строку
#     `**Active plan:** \`plans/<basename>\` — <title>`.
#     Если маркеров нет — добавляются после заголовка `## Active plan`
#     или в конец файла.
#
# Exit codes: 0 OK, 1 usage/missing file, 2 parse error.

set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

PLAN_FILE="${1:?Usage: mb-plan-sync.sh <plan-file> [mb_path]}"
MB_PATH=$(mb_resolve_path "${2:-}")

if [ ! -f "$PLAN_FILE" ]; then
  echo "[error] План не найден: $PLAN_FILE" >&2
  exit 1
fi

CHECKLIST="$MB_PATH/checklist.md"
PLAN_MD="$MB_PATH/plan.md"

[ -f "$CHECKLIST" ] || {
  echo "[error] checklist.md не найден: $CHECKLIST" >&2
  exit 1
}
[ -f "$PLAN_MD" ] || {
  echo "[error] plan.md не найден: $PLAN_MD" >&2
  exit 1
}

BASENAME=$(basename "$PLAN_FILE")

# ═══ Извлечь title плана (первый H1 после опционального префикса) ═══
plan_title=$(awk '
  /^# /{
    sub(/^# (План|Plan)[:：][[:space:]]*/, "")
    sub(/^# /, "")
    print
    exit
  }
' "$PLAN_FILE")
[ -n "$plan_title" ] || plan_title="$BASENAME"

# ═══ Парсинг этапов ═══
# Primary: маркеры <!-- mb-stage:N --> → следующая строка ### Этап N: <name>.
# Fallback: если маркеров нет — парсим ### Этап N: <name> напрямую.
# Вывод: tab-separated (N<TAB>name), по строке на этап.
parse_stages() {
  awk '
    BEGIN { use_markers = 0 }
    /<!-- mb-stage:[0-9]+ -->/ {
      use_markers = 1
      match($0, /[0-9]+/)
      pending = substr($0, RSTART, RLENGTH)
      next
    }
    pending != "" && /^### Этап [0-9]+:/ {
      sub(/^### Этап [0-9]+:[[:space:]]*/, "")
      printf "%s\t%s\n", pending, $0
      pending = ""
      next
    }
    END {
      if (use_markers == 0) exit 42
    }
  ' "$PLAN_FILE"
}

stages=$(parse_stages) || rc=$?
rc=${rc:-0}

if [ "$rc" -eq 42 ] || [ -z "$stages" ]; then
  # Fallback — нет маркеров, парсим ### напрямую
  stages=$(awk '
    /^### Этап [0-9]+:/ {
      line = $0
      match(line, /[0-9]+/)
      n = substr(line, RSTART, RLENGTH)
      sub(/^### Этап [0-9]+:[[:space:]]*/, "", line)
      printf "%s\t%s\n", n, line
    }
  ' "$PLAN_FILE")
fi

if [ -z "$stages" ]; then
  echo "[error] Не удалось извлечь этапы из $PLAN_FILE" >&2
  exit 2
fi

# ═══ Append отсутствующих секций в checklist ═══
append_missing_stages() {
  local checklist="$1" stages="$2"
  local tmp
  tmp=$(mktemp)
  cp "$checklist" "$tmp"

  local added=0
  while IFS=$'\t' read -r n name; do
    [ -n "$n" ] || continue
    # Проверяем присутствие секции `## Этап N:` (без учёта ✅/названия)
    if grep -qE "^## Этап ${n}:" "$tmp"; then
      continue
    fi
    # Добавляем в конец
    {
      printf '\n## Этап %s: %s\n' "$n" "$name"
      printf -- '- ⬜ %s\n' "$name"
    } >> "$tmp"
    added=$((added + 1))
  done <<< "$stages"

  mv "$tmp" "$checklist"
  printf '%s\n' "$added"
}

added_count=$(append_missing_stages "$CHECKLIST" "$stages")

# ═══ Обновить Active plan блок в plan.md ═══
update_active_plan_block() {
  local plan_md="$1" basename="$2" title="$3"
  local tmp
  tmp=$(mktemp)

  local new_line="**Active plan:** \`plans/$basename\` — $title"

  if grep -q '<!-- mb-active-plan -->' "$plan_md"; then
    # Есть маркеры — заменяем содержимое между ними
    awk -v newline="$new_line" '
      BEGIN { inside = 0 }
      /<!-- mb-active-plan -->/ {
        print
        print newline
        inside = 1
        next
      }
      /<!-- \/mb-active-plan -->/ {
        inside = 0
        print
        next
      }
      !inside { print }
    ' "$plan_md" > "$tmp"
  else
    # Маркеров нет — вставляем блок после `## Active plan` или добавляем в конец
    if grep -qE '^## Active plan[[:space:]]*$' "$plan_md"; then
      awk -v newline="$new_line" '
        /^## Active plan[[:space:]]*$/ {
          print
          print ""
          print "<!-- mb-active-plan -->"
          print newline
          print "<!-- /mb-active-plan -->"
          inserted = 1
          next
        }
        { print }
      ' "$plan_md" > "$tmp"
    else
      cp "$plan_md" "$tmp"
      {
        printf '\n## Active plan\n\n'
        printf '<!-- mb-active-plan -->\n'
        printf '%s\n' "$new_line"
        printf '<!-- /mb-active-plan -->\n'
      } >> "$tmp"
    fi
  fi

  mv "$tmp" "$plan_md"
}

update_active_plan_block "$PLAN_MD" "$BASENAME" "$plan_title"

# ═══ Report ═══
stage_count=$(printf '%s\n' "$stages" | grep -c . || true)
echo "[sync] plan=$BASENAME stages=$stage_count added=$added_count"
