#!/usr/bin/env bash
# mb-drift.sh — 8 deterministic drift checkers для Memory Bank (без AI).
#
# Usage:
#   mb-drift.sh [project-dir]
#
# Output (stdout): key=value
#   drift_check_<name>=ok|warn|skip
#   drift_warnings=N
# Diagnostics (stderr): '[drift:<name>]' строки
#
# Exit: 0 если drift_warnings=0, 1 иначе.

set -u

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

DIR="${1:-.}"
MB="$DIR/.memory-bank"
STALE_DAYS=30
WARNINGS=0

if [ ! -d "$MB" ]; then
  echo "drift_warnings=1"
  echo "drift_check_bank=warn"
  echo "[drift:bank] .memory-bank/ not found in $DIR" >&2
  exit 1
fi

_mtime() { stat -f%m "$1" 2>/dev/null || stat -c%Y "$1" 2>/dev/null || echo 0; }

warn() {
  echo "drift_check_${1}=warn"
  echo "[drift:${1}] ${2}" >&2
  WARNINGS=$(( WARNINGS + 1 ))
}

ok()   { echo "drift_check_${1}=ok"; }
skip() { echo "drift_check_${1}=skip"; echo "[drift:${1} skipped] ${2}" >&2; }

# ═══ 1. path — ссылки на файлы в MB существуют ═══
check_path() {
  local count=0 file
  for file in "$MB"/STATUS.md "$MB"/plan.md "$MB"/checklist.md "$MB"/BACKLOG.md; do
    [ -f "$file" ] || continue
    while read -r ref; do
      [ -z "$ref" ] && continue
      if [ ! -e "$MB/$ref" ]; then
        count=$(( count + 1 ))
        echo "  - $(basename "$file") -> $ref not found" >&2
      fi
    done < <(grep -oE '(notes|plans|reports|experiments)/[A-Za-z0-9_\-]+\.md' "$file" 2>/dev/null | sort -u)
  done
  if [ "$count" -gt 0 ]; then warn path "$count broken references"; else ok path; fi
}

# ═══ 2. staleness — core files моложе 30 дней ═══
check_staleness() {
  local count=0 now file name age
  now=$(date +%s)
  for file in "$MB"/STATUS.md "$MB"/plan.md "$MB"/checklist.md "$MB"/progress.md; do
    [ -f "$file" ] || continue
    age=$(( (now - $(_mtime "$file")) / 86400 ))
    if [ "$age" -gt "$STALE_DAYS" ]; then
      name=$(basename "$file")
      count=$(( count + 1 ))
      echo "  - $name не обновлялся $age дней (порог $STALE_DAYS)" >&2
    fi
  done
  if [ "$count" -gt 0 ]; then warn staleness "$count stale core files"; else ok staleness; fi
}

# ═══ 3. script-coverage — `bash scripts/X.sh` references существуют ═══
check_script_coverage() {
  local count=0 file ref
  for file in "$MB"/STATUS.md "$MB"/plan.md "$MB"/checklist.md "$MB"/BACKLOG.md; do
    [ -f "$file" ] || continue
    while read -r ref; do
      [ -z "$ref" ] && continue
      if [ ! -e "$DIR/$ref" ] && [ ! -e "$HOME/.claude/skills/memory-bank/$ref" ]; then
        count=$(( count + 1 ))
        echo "  - $(basename "$file") -> $ref not found" >&2
      fi
    done < <(grep -oE 'bash scripts/[A-Za-z0-9_\-]+\.sh' "$file" 2>/dev/null | awk '{print $2}' | sort -u)
  done
  if [ "$count" -gt 0 ]; then warn script_coverage "$count missing scripts"; else ok script_coverage; fi
}

# ═══ 4. dependency — Python версия в STATUS vs pyproject.toml ═══
check_dependency() {
  local py_status py_proj
  if [ ! -f "$DIR/pyproject.toml" ] && [ ! -f "$DIR/package.json" ] && [ ! -f "$DIR/go.mod" ]; then
    skip dependency "no project deps file"
    return
  fi
  # Сравниваем Python: "Python 3.X" в STATUS vs requires-python в pyproject
  if [ -f "$DIR/pyproject.toml" ] && [ -f "$MB/STATUS.md" ]; then
    py_status=$(grep -oE 'Python[[:space:]]+3\.[0-9]+' "$MB/STATUS.md" 2>/dev/null | head -1 | grep -oE '3\.[0-9]+' || true)
    py_proj=$(grep -oE 'requires-python[^"]*"[^"]+' "$DIR/pyproject.toml" 2>/dev/null | grep -oE '3\.[0-9]+' | head -1 || true)
    if [ -n "$py_status" ] && [ -n "$py_proj" ] && [ "$py_status" != "$py_proj" ]; then
      warn dependency "STATUS Python=$py_status vs pyproject=$py_proj"
      return
    fi
  fi
  ok dependency
}

# ═══ 5. cross-file — числовая консистентность MB-файлов ═══
# Проверяем pattern "NNN <unit>" где unit = tests|bats|pytest — должен совпадать
# между STATUS.md и checklist.md/progress.md если упомянут в обоих.
check_cross_file() {
  local st ch count=0 other
  [ -f "$MB/STATUS.md" ] || { ok cross_file; return; }
  # Извлекаем первый "N bats green" из STATUS.
  st=$(grep -oE '[0-9]+ bats green' "$MB/STATUS.md" 2>/dev/null | head -1 | awk '{print $1}' || true)
  if [ -n "${st:-}" ]; then
    for other in "$MB/checklist.md" "$MB/progress.md"; do
      [ -f "$other" ] || continue
      ch=$(grep -oE '[0-9]+ bats green' "$other" 2>/dev/null | head -1 | awk '{print $1}' || true)
      if [ -n "${ch:-}" ] && [ "$ch" != "$st" ]; then
        count=$(( count + 1 ))
        echo "  - STATUS=$st tests vs $(basename "$other")=$ch" >&2
      fi
    done
  fi
  if [ "$count" -gt 0 ]; then warn cross_file "$count mismatches"; else ok cross_file; fi
}

# ═══ 6. index-sync — index.json свежее всех notes ═══
check_index_sync() {
  local idx_mt note_mt file
  if [ ! -f "$MB/index.json" ]; then
    skip index_sync "no index.json"
    return
  fi
  idx_mt=$(_mtime "$MB/index.json")
  for file in "$MB"/notes/*.md; do
    [ -f "$file" ] || continue
    note_mt=$(_mtime "$file")
    if [ "$note_mt" -gt "$idx_mt" ]; then
      warn index_sync "$(basename "$file") новее index.json"
      return
    fi
  done
  ok index_sync
}

# ═══ 7. command — `npm run X` / `make X` references существуют ═══
check_command() {
  local count=0 file target
  # npm run X
  if [ -f "$DIR/package.json" ]; then
    for file in "$MB"/STATUS.md "$MB"/plan.md "$MB"/checklist.md; do
      [ -f "$file" ] || continue
      while read -r target; do
        [ -z "$target" ] && continue
        if ! grep -qE "\"$target\"[[:space:]]*:" "$DIR/package.json" 2>/dev/null; then
          count=$(( count + 1 ))
          echo "  - $(basename "$file") -> npm run $target (no script)" >&2
        fi
      done < <(grep -oE 'npm run [A-Za-z0-9_\-]+' "$file" 2>/dev/null | awk '{print $3}' | sort -u)
    done
  fi
  # make X
  if [ -f "$DIR/Makefile" ]; then
    for file in "$MB"/STATUS.md "$MB"/plan.md; do
      [ -f "$file" ] || continue
      while read -r target; do
        [ -z "$target" ] && continue
        if ! grep -qE "^$target:" "$DIR/Makefile" 2>/dev/null; then
          count=$(( count + 1 ))
          echo "  - $(basename "$file") -> make $target (no target)" >&2
        fi
      done < <(grep -oE 'make [A-Za-z][A-Za-z0-9_\-]+' "$file" 2>/dev/null | awk '{print $2}' | sort -u)
    done
  fi
  if [ "$count" -gt 0 ]; then warn command "$count missing commands"; else ok command; fi
}

# ═══ 8. frontmatter — notes YAML валиден (fence close, бандл тег) ═══
check_frontmatter() {
  local count=0 file
  for file in "$MB"/notes/*.md; do
    [ -f "$file" ] || continue
    # Первая непустая строка должна быть ---; ищем закрывающий fence до EOF.
    local has_fence_open has_fence_close
    has_fence_open=$(head -1 "$file" | grep -c '^---$' || true)
    if [ "$has_fence_open" -eq 0 ]; then
      continue  # нет frontmatter — не drift, просто note без шапки
    fi
    has_fence_close=$(awk 'NR>1 && /^---$/ {print; exit}' "$file" | wc -l | tr -d ' ')
    if [ "$has_fence_close" -eq 0 ]; then
      count=$(( count + 1 ))
      echo "  - $(basename "$file") frontmatter не закрыт" >&2
    fi
  done
  if [ "$count" -gt 0 ]; then warn frontmatter "$count malformed notes"; else ok frontmatter; fi
}

# ═══ Запуск всех проверок ═══
check_path
check_staleness
check_script_coverage
check_dependency
check_cross_file
check_index_sync
check_command
check_frontmatter

echo "drift_warnings=$WARNINGS"

[ "$WARNINGS" -eq 0 ] && exit 0 || exit 1
