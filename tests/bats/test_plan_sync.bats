#!/usr/bin/env bats
# Tests for scripts/mb-plan-sync.sh and scripts/mb-plan-done.sh.
#
# Contract (sync):
#   Input:  plan-file (path to .md with <!-- mb-stage:N --> markers)
#   Effects:
#     - checklist.md: для каждого (N, name) пары из плана — если нет секции
#       `## Этап N: <name>` — append `## Этап N: <name>\n- ⬜ <name>\n`.
#     - plan.md: блок между `<!-- mb-active-plan -->` и `<!-- /mb-active-plan -->`
#       заменяется на `**Active plan:** \`plans/<basename>\` — <title>`.
#     - Идемпотентно: повторный запуск → 0 diff.
#
# Contract (done):
#   - Все `- ⬜` внутри секций этапов плана в checklist.md → `- ✅`.
#   - `mv <plan-file> <mb>/plans/done/<basename>`.
#   - В plan.md блок между `<!-- mb-active-plan -->` и `<!-- /mb-active-plan -->`
#     → пустой (или заменяется на "No active plan").

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SYNC="$REPO_ROOT/scripts/mb-plan-sync.sh"
  DONE="$REPO_ROOT/scripts/mb-plan-done.sh"

  TMPROOT="$(mktemp -d)"
  TMPBANK="$TMPROOT/.memory-bank"
  mkdir -p "$TMPBANK/plans/done"

  # Plan with stage markers
  PLAN_FILE="$TMPBANK/plans/2026-04-19_refactor_skill-v2.md"
  cat > "$PLAN_FILE" <<'EOF'
# План: refactor — skill-v2

## Контекст

Test plan.

## Этапы

<!-- mb-stage:1 -->
### Этап 1: DRY-утилиты

Что сделать: create _lib.sh.

<!-- mb-stage:2 -->
### Этап 2: Language-agnostic metrics

Что сделать: create mb-metrics.sh.

<!-- mb-stage:3 -->
### Этап 3: codebase-mapper

Что сделать: adapt agent.
EOF

  # Minimal core files
  cat > "$TMPBANK/checklist.md" <<'EOF'
# Project — Чеклист

## Этап 0: Dogfood init ✅
- ✅ инициализация
EOF

  cat > "$TMPBANK/plan.md" <<'EOF'
# Project — План

## Текущий фокус

Test focus.

## Active plan

<!-- mb-active-plan -->
<!-- /mb-active-plan -->

## Ближайшие шаги

1. test
EOF
}

teardown() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}

# ═══════════════════════════════════════════════════════════════
# mb-plan-sync.sh
# ═══════════════════════════════════════════════════════════════

@test "sync: script exists and is executable" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  [ -x "$SYNC" ]
}

@test "sync: parses mb-stage markers from plan" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  run bash "$SYNC" "$PLAN_FILE" "$TMPBANK"
  [ "$status" -eq 0 ]
}

@test "sync: appends missing stages to checklist" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  run bash "$SYNC" "$PLAN_FILE" "$TMPBANK"
  [ "$status" -eq 0 ]

  run cat "$TMPBANK/checklist.md"
  [[ "$output" == *"## Этап 1: DRY-утилиты"* ]]
  [[ "$output" == *"## Этап 2: Language-agnostic metrics"* ]]
  [[ "$output" == *"## Этап 3: codebase-mapper"* ]]
}

@test "sync: existing stage not duplicated" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  # Pre-populate checklist with Этап 1 already
  cat >> "$TMPBANK/checklist.md" <<'EOF'

## Этап 1: DRY-утилиты ✅
- ✅ custom item
EOF

  bash "$SYNC" "$PLAN_FILE" "$TMPBANK"
  # Count occurrences of "## Этап 1:" — should be 1
  count=$(grep -c "^## Этап 1:" "$TMPBANK/checklist.md")
  [ "$count" -eq 1 ]
  # Custom item preserved
  grep -q "custom item" "$TMPBANK/checklist.md"
}

@test "sync: idempotent — double run equals single run" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  bash "$SYNC" "$PLAN_FILE" "$TMPBANK"
  first_checksum=$(shasum "$TMPBANK/checklist.md" "$TMPBANK/plan.md" | shasum)

  bash "$SYNC" "$PLAN_FILE" "$TMPBANK"
  second_checksum=$(shasum "$TMPBANK/checklist.md" "$TMPBANK/plan.md" | shasum)

  [ "$first_checksum" = "$second_checksum" ]
}

@test "sync: updates Active plan block in plan.md" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  bash "$SYNC" "$PLAN_FILE" "$TMPBANK"

  run cat "$TMPBANK/plan.md"
  [[ "$output" == *"2026-04-19_refactor_skill-v2.md"* ]]
  [[ "$output" == *"refactor — skill-v2"* ]]
}

@test "sync: Active plan block stays within markers" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  bash "$SYNC" "$PLAN_FILE" "$TMPBANK"

  # Открывающий и закрывающий маркеры должны остаться ровно по одному
  open_count=$(grep -c "<!-- mb-active-plan -->" "$TMPBANK/plan.md")
  close_count=$(grep -c "<!-- /mb-active-plan -->" "$TMPBANK/plan.md")
  [ "$open_count" -eq 1 ]
  [ "$close_count" -eq 1 ]
}

@test "sync: fallback to regex when no mb-stage markers" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  cat > "$PLAN_FILE" <<'EOF'
# План: fix — legacy-plan

## Этапы

### Этап 1: fix bug A
content

### Этап 2: fix bug B
content
EOF

  run bash "$SYNC" "$PLAN_FILE" "$TMPBANK"
  [ "$status" -eq 0 ]

  run cat "$TMPBANK/checklist.md"
  [[ "$output" == *"## Этап 1: fix bug A"* ]]
  [[ "$output" == *"## Этап 2: fix bug B"* ]]
}

@test "sync: creates Active plan markers if plan.md lacks them" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  # plan.md без маркеров
  cat > "$TMPBANK/plan.md" <<'EOF'
# Plan

## Active plan

Empty.
EOF

  run bash "$SYNC" "$PLAN_FILE" "$TMPBANK"
  [ "$status" -eq 0 ]

  run cat "$TMPBANK/plan.md"
  [[ "$output" == *"<!-- mb-active-plan -->"* ]]
  [[ "$output" == *"<!-- /mb-active-plan -->"* ]]
  [[ "$output" == *"2026-04-19_refactor_skill-v2.md"* ]]
}

@test "sync: fails gracefully when plan-file missing" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  run bash "$SYNC" "$TMPBANK/plans/nonexistent.md" "$TMPBANK"
  [ "$status" -ne 0 ]
  [[ "$output$stderr" == *"не найден"* || "$output$stderr" == *"not found"* ]]
}

@test "sync: checklist with ⬜ item per stage" {
  [ -f "$SYNC" ] || skip "mb-plan-sync.sh not implemented yet (TDD red)"
  bash "$SYNC" "$PLAN_FILE" "$TMPBANK"

  run cat "$TMPBANK/checklist.md"
  # Each added section should have a ⬜ item
  [[ "$output" == *"- ⬜ DRY-утилиты"* ]]
  [[ "$output" == *"- ⬜ Language-agnostic metrics"* ]]
  [[ "$output" == *"- ⬜ codebase-mapper"* ]]
}

# ═══════════════════════════════════════════════════════════════
# mb-plan-done.sh
# ═══════════════════════════════════════════════════════════════

@test "done: script exists and is executable" {
  [ -f "$DONE" ] || skip "mb-plan-done.sh not implemented yet (TDD red)"
  [ -x "$DONE" ]
}

@test "done: moves plan file to plans/done/" {
  [ -f "$DONE" ] || skip "mb-plan-done.sh not implemented yet (TDD red)"
  # Prep: sync first so checklist has sections
  [ -f "$SYNC" ] && bash "$SYNC" "$PLAN_FILE" "$TMPBANK"

  basename_file=$(basename "$PLAN_FILE")
  run bash "$DONE" "$PLAN_FILE" "$TMPBANK"
  [ "$status" -eq 0 ]

  [ -f "$TMPBANK/plans/done/$basename_file" ]
  [ ! -f "$PLAN_FILE" ]
}

@test "done: closes all ⬜ in plan stages to ✅" {
  [ -f "$DONE" ] || skip "mb-plan-done.sh not implemented yet (TDD red)"
  [ -f "$SYNC" ] && bash "$SYNC" "$PLAN_FILE" "$TMPBANK"

  # Confirm ⬜ exist before
  run grep -c "^- ⬜" "$TMPBANK/checklist.md"
  [ "$output" -ge 3 ]

  bash "$DONE" "$PLAN_FILE" "$TMPBANK"

  # After done — no ⬜ left in plan stages
  ! grep -q "^- ⬜ DRY-утилиты" "$TMPBANK/checklist.md"
  ! grep -q "^- ⬜ Language-agnostic metrics" "$TMPBANK/checklist.md"
  ! grep -q "^- ⬜ codebase-mapper" "$TMPBANK/checklist.md"

  # Instead they should be ✅
  grep -q "^- ✅ DRY-утилиты" "$TMPBANK/checklist.md"
  grep -q "^- ✅ Language-agnostic metrics" "$TMPBANK/checklist.md"
  grep -q "^- ✅ codebase-mapper" "$TMPBANK/checklist.md"
}

@test "done: clears Active plan block in plan.md" {
  [ -f "$DONE" ] || skip "mb-plan-done.sh not implemented yet (TDD red)"
  [ -f "$SYNC" ] && bash "$SYNC" "$PLAN_FILE" "$TMPBANK"

  bash "$DONE" "$PLAN_FILE" "$TMPBANK"

  # After done, Active plan content inside markers should be cleared
  run cat "$TMPBANK/plan.md"
  [[ "$output" != *"2026-04-19_refactor_skill-v2.md"* ]]
  # Markers still there (idempotent with next sync)
  [[ "$output" == *"<!-- mb-active-plan -->"* ]]
  [[ "$output" == *"<!-- /mb-active-plan -->"* ]]
}

@test "done: fails when plan-file not in plans/ of mb_path" {
  [ -f "$DONE" ] || skip "mb-plan-done.sh not implemented yet (TDD red)"
  # File outside plans/
  stray="$TMPROOT/stray-plan.md"
  cp "$PLAN_FILE" "$stray"

  run bash "$DONE" "$stray" "$TMPBANK"
  [ "$status" -ne 0 ]
}

@test "done: idempotent — re-running after move fails gracefully" {
  [ -f "$DONE" ] || skip "mb-plan-done.sh not implemented yet (TDD red)"
  [ -f "$SYNC" ] && bash "$SYNC" "$PLAN_FILE" "$TMPBANK"
  bash "$DONE" "$PLAN_FILE" "$TMPBANK"

  # Second call: plan already moved — should error, не ломать состояние
  run bash "$DONE" "$PLAN_FILE" "$TMPBANK"
  [ "$status" -ne 0 ]
}

@test "done: preserves other stages in checklist" {
  [ -f "$DONE" ] || skip "mb-plan-done.sh not implemented yet (TDD red)"
  [ -f "$SYNC" ] && bash "$SYNC" "$PLAN_FILE" "$TMPBANK"

  bash "$DONE" "$PLAN_FILE" "$TMPBANK"

  # Этап 0 (pre-existing) нетронут
  grep -q "^## Этап 0: Dogfood init" "$TMPBANK/checklist.md"
  grep -q "^- ✅ инициализация" "$TMPBANK/checklist.md"
}
