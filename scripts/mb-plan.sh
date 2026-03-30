#!/usr/bin/env bash
# mb-plan.sh — создание файла плана в Memory Bank
# Usage: mb-plan.sh <type> <topic> [mb_path]
# Types: feature, fix, refactor, experiment
# Создаёт plans/YYYY-MM-DD_<type>_<topic>.md с шаблоном

set -euo pipefail

TYPE="${1:?Usage: mb-plan.sh <type> <topic> [mb_path]. Types: feature, fix, refactor, experiment}"
TOPIC="${2:?Usage: mb-plan.sh <type> <topic> [mb_path]}"

# Auto-resolve from .claude-workspace if no explicit path given
if [[ -z "${3:-}" ]] && [[ -f ".claude-workspace" ]]; then
  _WS_STORAGE=$(grep "^storage:" .claude-workspace 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "local")
  if [[ "$_WS_STORAGE" == "external" ]]; then
    _WS_PROJECT_ID=$(grep "^project_id:" .claude-workspace 2>/dev/null | awk '{print $2}' | tr -d '"')
    MB_PATH="$HOME/.claude/workspaces/$_WS_PROJECT_ID/.memory-bank"
  else
    MB_PATH=".memory-bank"
  fi
else
  MB_PATH="${3:-.memory-bank}"
fi
PLANS_DIR="$MB_PATH/plans"

# Validate type
case "$TYPE" in
  feature|fix|refactor|experiment) ;;
  *) echo "Неизвестный тип: $TYPE. Допустимые: feature, fix, refactor, experiment" >&2; exit 1 ;;
esac

# Sanitize topic
SAFE_TOPIC=$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')

DATE=$(date +"%Y-%m-%d")
FILENAME="${DATE}_${TYPE}_${SAFE_TOPIC}.md"
FILEPATH="$PLANS_DIR/$FILENAME"

mkdir -p "$PLANS_DIR"

if [[ -f "$FILEPATH" ]]; then
  echo "Файл уже существует: $FILEPATH" >&2
  exit 1
fi

cat > "$FILEPATH" << 'TEMPLATE'
# План: TYPE — TOPIC

## Контекст

**Проблема:** <!-- Что промптило создание этого плана -->

**Ожидаемый результат:** <!-- Что должно получиться -->

**Связанные файлы:**
- <!-- ссылки на код, спеки, эксперименты -->

---

## Этапы

### Этап 1: <!-- название -->

**Что сделать:**
- <!-- конкретные действия -->

**Тестирование (TDD — тесты ПЕРЕД реализацией):**
- <!-- unit тесты: что проверяем, edge cases -->
- <!-- integration тесты: какие компоненты вместе -->

**DoD (Definition of Done):**
- [ ] <!-- конкретный, измеримый критерий (SMART) -->
- [ ] <!-- тесты проходят -->
- [ ] <!-- lint clean -->

**Правила кода:** SOLID, DRY, KISS, YAGNI, Clean Architecture

---

### Этап 2: <!-- название -->

**Что сделать:**
-

**Тестирование (TDD):**
-

**DoD:**
- [ ]

---

## Риски и mitigation

| Риск | Вероятность | Mitigation |
|------|------------|------------|
| <!-- риск --> | <!-- H/M/L --> | <!-- как предотвратить --> |

## Gate (критерий успеха плана)

<!-- Когда план считается выполненным целиком -->
TEMPLATE

# Подставить type и topic в заголовок
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|TYPE|$TYPE|g; s|TOPIC|$SAFE_TOPIC|g" "$FILEPATH"
else
  sed -i "s|TYPE|$TYPE|g; s|TOPIC|$SAFE_TOPIC|g" "$FILEPATH"
fi

echo "$FILEPATH"
