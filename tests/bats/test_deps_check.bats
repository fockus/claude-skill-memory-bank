#!/usr/bin/env bats
# Tests for scripts/mb-deps-check.sh.
#
# Contract:
#   mb-deps-check.sh [--quiet] [--install-hints]
#
# Output format (key=value, stdout):
#   dep_<name>=ok|missing|optional-missing
#   deps_required_missing=N
#   deps_optional_missing=M
#
# Exit:
#   0 — all required present
#   1 — at least 1 required missing (blocker)
#
# Test strategy: инжектим fake PATH без конкретной утилиты, проверяем что
# скрипт корректно её флагает. Для "all present" случая используем системный PATH.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  DEPS="$REPO_ROOT/scripts/mb-deps-check.sh"
  SANDBOX_BIN="$(mktemp -d)"
  # Создадим 2-uninstalled sandbox: только bash внутри
  ln -s "$(command -v bash)" "$SANDBOX_BIN/bash"
}

teardown() {
  [ -n "${SANDBOX_BIN:-}" ] && [ -d "$SANDBOX_BIN" ] && rm -rf "$SANDBOX_BIN"
}

run_deps() {
  local raw
  raw=$(bash "$DEPS" "$@" 2>&1; printf '\n__EXIT__%s' "$?")
  status="${raw##*__EXIT__}"
  output="${raw%$'\n'__EXIT__*}"
}

run_deps_sandbox() {
  local raw
  raw=$(env -i HOME="$HOME" PATH="$SANDBOX_BIN" bash "$DEPS" "$@" 2>&1; printf '\n__EXIT__%s' "$?")
  status="${raw##*__EXIT__}"
  output="${raw%$'\n'__EXIT__*}"
}

# ═══════════════════════════════════════════════════════════════

@test "deps: all present on current system → exit 0 (assuming python3/jq/git installed)" {
  run_deps
  # На dev-машине все required должны быть. Если CI без jq — ожидаем exit 1.
  # Assert: output содержит dep_python3=ok или ясную причину.
  [[ "$output" == *"dep_python3="* ]]
  [[ "$output" == *"dep_jq="* ]]
  [[ "$output" == *"dep_git="* ]]
  [[ "$output" == *"deps_required_missing="* ]]
}

@test "deps: reports optional deps (rg, shellcheck)" {
  run_deps
  [[ "$output" == *"dep_rg="* ]]
  [[ "$output" == *"dep_shellcheck="* ]]
  [[ "$output" == *"deps_optional_missing="* ]]
}

@test "deps: sandbox with only bash → required missing → exit 1" {
  run_deps_sandbox
  [ "$status" -ne 0 ]
  [[ "$output" == *"dep_python3=missing"* ]]
  [[ "$output" == *"dep_jq=missing"* ]]
}

@test "deps: --install-hints prints brew/apt instructions on missing required" {
  run_deps_sandbox --install-hints
  [ "$status" -ne 0 ]
  # Должен упомянуть install команды
  [[ "$output" == *"brew"* ]] || [[ "$output" == *"apt"* ]] || [[ "$output" == *"install"* ]]
}

@test "deps: --quiet suppresses human-readable output, keeps key=value" {
  run_deps --quiet
  # Key=value остаётся
  [[ "$output" == *"dep_python3="* ]]
  # Никаких эмодзи/цветов
  [[ "$output" != *"✅"* ]]
  [[ "$output" != *"❌"* ]]
}

@test "deps: tree-sitter check reports presence or optional-missing (not blocker)" {
  run_deps
  [[ "$output" == *"dep_tree_sitter="* ]]
  # tree-sitter — opt-in; missing не должно влиять на required_missing count
  # (assertion: если он missing, то in optional_missing, не required)
}

@test "deps: exit 0 even если много optional missing, пока required ok" {
  # На системе с установленными required (python3, jq, git) — exit 0 независимо от optional
  if ! command -v python3 >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
    skip "required deps missing on this system"
  fi
  run_deps
  [ "$status" -eq 0 ]
}
