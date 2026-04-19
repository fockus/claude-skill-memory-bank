#!/usr/bin/env bats
# Tests for scripts/mb-compact.sh — status-based compaction decay.
#
# Архивация требует (age > threshold) AND (done-signal):
#   - done-signal для планов:
#       • файл в plans/done/ — primary (уже закрыт через mb-plan-done.sh)
#       • ИЛИ путь упомянут в checklist.md строкой с ✅/[x]
#       • ИЛИ упомянут в progress.md/STATUS.md как "завершён|done|closed|shipped"
#   - done-signal для notes: frontmatter importance: low + нет активных референсов
#
# Active planы (not done) НЕ трогаются даже >180d → warning only.
#
# Output: key=value на stdout, reasoning per candidate.
# Exit: 0 success, 1 error.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  COMPACT="$REPO_ROOT/scripts/mb-compact.sh"

  PROJECT="$(mktemp -d)"
  MB="$PROJECT/.memory-bank"
  mkdir -p "$MB/notes" "$MB/plans/done" "$MB/reports"
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

# Run compact, capturing stdout/stderr and exit code.
run_compact() {
  local raw
  raw=$(cd "$PROJECT" && bash "$COMPACT" "$@" 2>&1; printf '\n__EXIT__%s' "$?")
  status="${raw##*__EXIT__}"
  output="${raw%$'\n'__EXIT__*}"
}

# Set mtime to N days ago (portable BSD/GNU touch -t).
set_mtime_days_ago() {
  local file="$1" days="$2"
  local ts
  # BSD date
  if ts=$(date -v-"${days}"d +"%Y%m%d%H%M" 2>/dev/null); then
    touch -t "$ts" "$file"
  else
    # GNU date
    ts=$(date -d "$days days ago" +"%Y%m%d%H%M")
    touch -t "$ts" "$file"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Contract — smoke
# ═══════════════════════════════════════════════════════════════

@test "compact: empty bank → drift_candidates=0 exit 0" {
  run_compact --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"candidates=0"* ]] || [[ "$output" == *"0 plans"* ]]
}

@test "compact: --dry-run is default (no args)" {
  run_compact
  [ "$status" -eq 0 ]
  # Нет изменений файлов
  [ ! -d "$MB/notes/archive" ]
}

# ═══════════════════════════════════════════════════════════════
# Plans — time threshold (60d default)
# ═══════════════════════════════════════════════════════════════

@test "compact: plan in plans/done/ <60d → не трогать (age too low)" {
  local p="$MB/plans/done/2026-03-15_feature_x.md"
  echo "# Plan X" > "$p"
  set_mtime_days_ago "$p" 30

  run_compact --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"plans/done/2026-03-15_feature_x.md"* ]] \
    || [[ "$output" == *"skip"*"2026-03-15"* ]]
}

@test "compact: plan in plans/done/ =61d → candidate for archival" {
  local p="$MB/plans/done/2026-02-18_feature_old.md"
  echo "# Plan Old" > "$p"
  set_mtime_days_ago "$p" 61

  run_compact --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-02-18_feature_old.md"* ]]
  [[ "$output" == *"archive"* ]] || [[ "$output" == *"candidate"* ]]
}

# ═══════════════════════════════════════════════════════════════
# Plans — status-based safety (CRITICAL)
# ═══════════════════════════════════════════════════════════════

@test "compact: active plan in plans/ (not done) + >180d → НЕ трогать" {
  local p="$MB/plans/2025-10-01_feature_active.md"
  echo "# Active Plan" > "$p"
  set_mtime_days_ago "$p" 200

  run_compact --dry-run
  [ "$status" -eq 0 ]
  # Не в кандидатах на archive
  [[ "$output" != *"archive: plans/2025-10-01"* ]]
  # Должен быть warning про старый active план
  [[ "$output" == *"2025-10-01"* ]]
  [[ "$output" == *"active"*"old"* ]] \
    || [[ "$output" == *"warning"* ]] \
    || [[ "$output" == *"не done"* ]] \
    || [[ "$output" == *"not done"* ]]
}

@test "compact: plan marked ✅ in checklist.md + >60d → done-signal → archive" {
  local p="$MB/plans/2026-02-18_feature_done_checklist.md"
  echo "# Plan" > "$p"
  set_mtime_days_ago "$p" 70
  # ✅ signal в checklist
  cat > "$MB/checklist.md" <<EOF
## Этап 1: X
- ✅ Работа по плану: plans/2026-02-18_feature_done_checklist.md
EOF

  run_compact --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-02-18_feature_done_checklist.md"* ]]
  [[ "$output" == *"archive"* ]] || [[ "$output" == *"candidate"* ]]
}

@test "compact: plan marked ⬜ в checklist + >180d → НЕ трогать (active)" {
  local p="$MB/plans/2025-09-01_feature_still_todo.md"
  echo "# Plan" > "$p"
  set_mtime_days_ago "$p" 230
  cat > "$MB/checklist.md" <<EOF
## Этап 1: Y
- ⬜ plans/2025-09-01_feature_still_todo.md — ещё делаем
EOF

  run_compact --dry-run
  [ "$status" -eq 0 ]
  # Не archive
  [[ "$output" != *"archive: plans/2025-09-01"* ]]
}

@test "compact: plan упомянут в progress.md как 'завершён' + >60d → archive" {
  local p="$MB/plans/2026-02-10_feature_progress_done.md"
  echo "# Plan" > "$p"
  set_mtime_days_ago "$p" 75
  cat > "$MB/progress.md" <<EOF
## 2026-02-15

- План 2026-02-10_feature_progress_done.md завершён
EOF

  run_compact --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-02-10_feature_progress_done.md"* ]]
  [[ "$output" == *"archive"* ]] || [[ "$output" == *"candidate"* ]]
}

# ═══════════════════════════════════════════════════════════════
# Notes — importance + age
# ═══════════════════════════════════════════════════════════════

@test "compact: low-importance note >90d → candidate" {
  local n="$MB/notes/2026-01-10_old_note.md"
  cat > "$n" <<EOF
---
type: note
importance: low
tags: [cleanup]
---
Old low-value note.
EOF
  set_mtime_days_ago "$n" 100

  run_compact --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-01-10_old_note.md"* ]]
  [[ "$output" == *"archive"* ]] || [[ "$output" == *"candidate"* ]]
}

@test "compact: medium-importance note >90d → НЕ тронуто" {
  local n="$MB/notes/2026-01-10_medium.md"
  cat > "$n" <<EOF
---
type: note
importance: medium
tags: []
---
Medium note.
EOF
  set_mtime_days_ago "$n" 100

  run_compact --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"archive: notes/2026-01-10_medium"* ]]
}

@test "compact: low note <90d → НЕ тронуто" {
  local n="$MB/notes/2026-04-01_recent_low.md"
  cat > "$n" <<EOF
---
type: note
importance: low
---
Recent low note.
EOF
  set_mtime_days_ago "$n" 20

  run_compact --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"archive: notes/2026-04-01"* ]]
}

@test "compact: low note >90d + referenced in plan.md → НЕ тронуто (safety)" {
  local n="$MB/notes/2026-01-05_referenced.md"
  cat > "$n" <<EOF
---
type: note
importance: low
---
Referenced from plan.
EOF
  set_mtime_days_ago "$n" 120
  cat > "$MB/plan.md" <<EOF
# План
См. также notes/2026-01-05_referenced.md
EOF

  run_compact --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"archive: notes/2026-01-05_referenced"* ]]
}

# ═══════════════════════════════════════════════════════════════
# --apply mechanics
# ═══════════════════════════════════════════════════════════════

@test "compact: --apply moves plan to BACKLOG archive + deletes file" {
  local p="$MB/plans/done/2026-01-01_archive_me.md"
  cat > "$p" <<EOF
# Archive Me

Outcome: success.
EOF
  set_mtime_days_ago "$p" 120

  run_compact --apply
  [ "$status" -eq 0 ]
  # Файл удалён
  [ ! -f "$p" ]
  # BACKLOG получил строку
  grep -q "archive_me" "$MB/BACKLOG.md"
  grep -q "Archived plans" "$MB/BACKLOG.md"
}

@test "compact: --apply moves note to notes/archive/" {
  local n="$MB/notes/2026-01-02_archive_low.md"
  cat > "$n" <<EOF
---
type: note
importance: low
---
Archivable note body line.
EOF
  set_mtime_days_ago "$n" 120

  run_compact --apply
  [ "$status" -eq 0 ]
  [ ! -f "$n" ]
  [ -f "$MB/notes/archive/2026-01-02_archive_low.md" ]
}

@test "compact: --apply идемпотентна (2 run подряд — 0 дополнительных изменений)" {
  local p="$MB/plans/done/2026-01-01_idem.md"
  echo "# Plan" > "$p"
  set_mtime_days_ago "$p" 80

  run_compact --apply
  [ "$status" -eq 0 ]

  local backlog_size1
  backlog_size1=$(wc -l < "$MB/BACKLOG.md")

  run_compact --apply
  [ "$status" -eq 0 ]

  local backlog_size2
  backlog_size2=$(wc -l < "$MB/BACKLOG.md")
  [ "$backlog_size1" -eq "$backlog_size2" ]
}

@test "compact: --apply обновляет .last-compact timestamp" {
  [ ! -f "$MB/.last-compact" ]
  run_compact --apply
  [ "$status" -eq 0 ]
  [ -f "$MB/.last-compact" ]
}

@test "compact: --dry-run НЕ создаёт .last-compact" {
  run_compact --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$MB/.last-compact" ]
}

# ═══════════════════════════════════════════════════════════════
# Error handling
# ═══════════════════════════════════════════════════════════════

@test "compact: broken frontmatter note → skip с warning, не блокирует batch" {
  # Хорошая нота, которая должна обработаться
  local good="$MB/notes/2026-01-01_good_low.md"
  cat > "$good" <<EOF
---
type: note
importance: low
---
Good note to archive.
EOF
  set_mtime_days_ago "$good" 100

  # Битая нота: невалидный frontmatter
  local bad="$MB/notes/2026-01-01_broken.md"
  cat > "$bad" <<EOF
---
type: [[[broken yaml
importance: low
---
Broken.
EOF
  set_mtime_days_ago "$bad" 100

  run_compact --dry-run
  [ "$status" -eq 0 ]
  # Хорошая попала в candidates
  [[ "$output" == *"2026-01-01_good_low.md"* ]]
}

@test "compact: missing .memory-bank/ → exit 1 с hint" {
  NOBANK="$(mktemp -d)"
  raw=$(cd "$NOBANK" && bash "$COMPACT" --dry-run 2>&1; printf '\n__EXIT__%s' "$?")
  status="${raw##*__EXIT__}"
  output="${raw%$'\n'__EXIT__*}"
  [ "$status" -ne 0 ]
  [[ "$output" == *".memory-bank"* ]] || [[ "$output" == *"not found"* ]]
  rm -rf "$NOBANK"
}

@test "compact: unknown flag → exit 1 с usage" {
  run_compact --unknown-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage"* ]] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"unknown"* ]]
}
