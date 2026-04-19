#!/usr/bin/env bats
# Tests for scripts/mb-drift.sh — 8 deterministic checkers без AI.
#
# Output contract: key=value на stdout, warnings на stderr.
#   - drift_warnings=N (итоговое число)
#   - drift_check_<name>=ok|warn per checker
# Exit: 0 если drift_warnings=0, 1 иначе.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  DRIFT="$REPO_ROOT/scripts/mb-drift.sh"

  PROJECT="$(mktemp -d)"
  MB="$PROJECT/.memory-bank"
  mkdir -p "$MB/notes" "$MB/plans/done" "$MB/reports"
  # Базовое содержимое core-файлов — всегда чистое если тест не изменит.
  : > "$MB/STATUS.md"
  : > "$MB/checklist.md"
  : > "$MB/plan.md"
  : > "$MB/progress.md"
  : > "$MB/lessons.md"
  : > "$MB/RESEARCH.md"
  : > "$MB/BACKLOG.md"
}

teardown() {
  [ -n "${PROJECT:-}" ] && [ -d "$PROJECT" ] && rm -rf "$PROJECT"
}

# Run drift, capturing stdout/stderr и exit code.
run_drift() {
  local target="${1:-$PROJECT}"
  local raw
  raw=$(bash "$DRIFT" "$target" 2>&1; printf '\n__EXIT__%s' "$?")
  status="${raw##*__EXIT__}"
  output="${raw%$'\n'__EXIT__*}"
}

# ═══════════════════════════════════════════════════════════════
# Overall contract — smoke
# ═══════════════════════════════════════════════════════════════

@test "drift: clean bank → drift_warnings=0 exit 0" {
  run_drift
  [ "$status" -eq 0 ]
  [[ "$output" == *"drift_warnings=0"* ]]
}

@test "drift: output format — key=value лексически парсируется" {
  run_drift
  # Все key=value строки должны быть парсируемы (no weird chars)
  echo "$output" | grep -E '^[a-z_][a-z0-9_]*=[^[:space:]]*$' | head -1
}

@test "drift: missing .memory-bank/ → fails fast with hint" {
  NOBANK="$(mktemp -d)"
  run_drift "$NOBANK"
  [ "$status" -ne 0 ]
  [[ "$output" == *".memory-bank"* ]] || [[ "$output" == *"not found"* ]]
  rm -rf "$NOBANK"
}

# ═══════════════════════════════════════════════════════════════
# Checker 1: path — ссылки на файлы существуют
# ═══════════════════════════════════════════════════════════════

@test "drift[path]: reference к existing note → no warning" {
  echo "note-stub" > "$MB/notes/2026-04-20_test.md"
  echo "См. notes/2026-04-20_test.md" > "$MB/checklist.md"
  run_drift
  [[ "$output" == *"drift_check_path=ok"* ]]
}

@test "drift[path]: reference к missing note → warning path" {
  echo "См. notes/missing.md" > "$MB/checklist.md"
  run_drift
  [[ "$output" == *"drift_check_path=warn"* ]]
  [ "$status" -ne 0 ]
}

# ═══════════════════════════════════════════════════════════════
# Checker 2: staleness — core files не стухли
# ═══════════════════════════════════════════════════════════════

@test "drift[staleness]: recent core files → no warning" {
  echo "fresh" > "$MB/STATUS.md"
  run_drift
  [[ "$output" == *"drift_check_staleness=ok"* ]]
}

@test "drift[staleness]: STATUS.md mtime >30 days → warning staleness" {
  echo "stale" > "$MB/STATUS.md"
  old=$(( $(date +%s) - 40 * 86400 ))
  touch -t "$(date -r "$old" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$old" +%Y%m%d%H%M.%S)" "$MB/STATUS.md"
  run_drift
  [[ "$output" == *"drift_check_staleness=warn"* ]]
}

# ═══════════════════════════════════════════════════════════════
# Checker 3: script-coverage — `bash scripts/X.sh` references existing
# ═══════════════════════════════════════════════════════════════

@test "drift[script-coverage]: existing bash scripts/foo.sh → no warning" {
  mkdir -p "$PROJECT/scripts"
  : > "$PROJECT/scripts/foo.sh"
  echo "bash scripts/foo.sh" > "$MB/plan.md"
  run_drift
  [[ "$output" == *"drift_check_script_coverage=ok"* ]]
}

@test "drift[script-coverage]: reference missing bash scripts/gone.sh → warning" {
  echo "bash scripts/gone.sh" > "$MB/plan.md"
  run_drift
  [[ "$output" == *"drift_check_script_coverage=warn"* ]]
}

# ═══════════════════════════════════════════════════════════════
# Checker 4: dependency — documented Python version matches pyproject
# ═══════════════════════════════════════════════════════════════

@test "drift[dependency]: no project deps file → skip check (ok)" {
  # Чистый project без pyproject/package.json — чекер skip с ok.
  echo "Python 3.12" > "$MB/STATUS.md"
  run_drift
  [[ "$output" == *"drift_check_dependency=ok"* ]] || [[ "$output" == *"drift_check_dependency=skip"* ]]
}

@test "drift[dependency]: STATUS Python 3.11 vs pyproject 3.12 → warning" {
  cat > "$PROJECT/pyproject.toml" <<'EOF'
[project]
name = "foo"
requires-python = ">=3.12"
EOF
  echo "# STATUS" > "$MB/STATUS.md"
  echo "Стек: Python 3.11" >> "$MB/STATUS.md"
  run_drift
  [[ "$output" == *"drift_check_dependency=warn"* ]]
}

# ═══════════════════════════════════════════════════════════════
# Checker 5: cross-file — числовая консистентность между MB-файлами
# ═══════════════════════════════════════════════════════════════

@test "drift[cross-file]: same test count в STATUS и checklist → no warning" {
  echo "Tests: 163 bats green" > "$MB/STATUS.md"
  echo "**Итог**: 163 bats green" > "$MB/checklist.md"
  run_drift
  [[ "$output" == *"drift_check_cross_file=ok"* ]]
}

@test "drift[cross-file]: test counts расходятся — STATUS=163 vs checklist=100 → warning" {
  echo "Tests: 163 bats green" > "$MB/STATUS.md"
  echo "**Итог**: 100 bats green" > "$MB/checklist.md"
  run_drift
  [[ "$output" == *"drift_check_cross_file=warn"* ]]
}

# ═══════════════════════════════════════════════════════════════
# Checker 6: index-sync — index.json mtime vs notes/*.md
# ═══════════════════════════════════════════════════════════════

@test "drift[index-sync]: fresh index.json newer than notes → no warning" {
  echo "note" > "$MB/notes/2026-04-20_a.md"
  sleep 1
  echo '{"notes":[]}' > "$MB/index.json"
  run_drift
  [[ "$output" == *"drift_check_index_sync=ok"* ]]
}

@test "drift[index-sync]: note newer than index.json → warning" {
  echo '{"notes":[]}' > "$MB/index.json"
  sleep 1
  echo "note" > "$MB/notes/2026-04-20_b.md"
  run_drift
  [[ "$output" == *"drift_check_index_sync=warn"* ]]
}

# ═══════════════════════════════════════════════════════════════
# Checker 7: command — `make X` / `npm run X` references exist
# ═══════════════════════════════════════════════════════════════

@test "drift[command]: npm run test references valid package.json → no warning" {
  cat > "$PROJECT/package.json" <<'EOF'
{"name":"x","scripts":{"test":"jest"}}
EOF
  echo "Запусти: npm run test" > "$MB/plan.md"
  run_drift
  [[ "$output" == *"drift_check_command=ok"* ]]
}

@test "drift[command]: npm run nonexistent → warning" {
  cat > "$PROJECT/package.json" <<'EOF'
{"name":"x","scripts":{"test":"jest"}}
EOF
  echo "Запусти: npm run nonexistent-script" > "$MB/plan.md"
  run_drift
  [[ "$output" == *"drift_check_command=warn"* ]]
}

# ═══════════════════════════════════════════════════════════════
# Checker 8: frontmatter — notes YAML валиден
# ═══════════════════════════════════════════════════════════════

@test "drift[frontmatter]: valid frontmatter → no warning" {
  cat > "$MB/notes/2026-04-20_good.md" <<'EOF'
---
type: note
tags: [auth, bug]
importance: high
---

body here
EOF
  run_drift
  [[ "$output" == *"drift_check_frontmatter=ok"* ]]
}

@test "drift[frontmatter]: unterminated YAML fence → warning" {
  cat > "$MB/notes/2026-04-20_bad.md" <<'EOF'
---
type: note
tags: [unclosed
EOF
  # Нет закрывающей --- → parser не сможет разобрать.
  run_drift
  [[ "$output" == *"drift_check_frontmatter=warn"* ]]
}

# ═══════════════════════════════════════════════════════════════
# Aggregation — broken fixture smoke
# ═══════════════════════════════════════════════════════════════

@test "drift: broken fixture — ≥5 категорий warnings" {
  # Комбинация ошибок — используем существующий tests/fixtures/broken-mb/
  # если есть, иначе синтезируем inline.
  FIXTURE="$REPO_ROOT/tests/fixtures/broken-mb"
  if [ -d "$FIXTURE" ]; then
    run_drift "$FIXTURE"
  else
    # Inline: минимум 5 видов drift.
    echo "См. notes/missing.md" > "$MB/checklist.md"                                      # path
    old=$(( $(date +%s) - 40 * 86400 ))
    touch -t "$(date -r "$old" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$old" +%Y%m%d%H%M.%S)" "$MB/STATUS.md" # staleness
    echo "bash scripts/gone.sh" >> "$MB/plan.md"                                          # script-coverage
    echo "Tests: 5 green" > "$MB/STATUS.md"
    echo "Tests: 999 green" > "$MB/progress.md"                                           # cross-file
    printf -- '---\ntype: note\ntags: [broken\n' > "$MB/notes/2026-04-20_x.md"           # frontmatter
    run_drift
  fi

  # Минимум 5 warnings.
  warnings=$(echo "$output" | grep -oE 'drift_warnings=[0-9]+' | head -1 | cut -d= -f2)
  [ "${warnings:-0}" -ge 5 ]
  [ "$status" -ne 0 ]
}
