# Memory Bank — Шаблоны

## Заметка (notes/)

Файл: `notes/YYYY-MM-DD_HH-MM_<topic>.md`

```markdown
# <Topic>
Date: YYYY-MM-DD HH:MM

## Что сделано
- <действие 1>
- <действие 2>
- <действие 3>

## Новые знания
- <вывод, паттерн, переиспользуемое решение>
- <что запомнить для будущих сессий>
```

5-15 строк. Знания, не хронология.

---

## Запись в progress.md (append)

```markdown
## YYYY-MM-DD

### <Тема>
- <что сделано, 3-5 пунктов>
- Тесты: N green, coverage X%
- Следующий шаг: <что дальше>
```

Дописывать ТОЛЬКО в конец файла. Не редактировать старые записи.

---

## Запись в lessons.md

```markdown
### <Название паттерна> (EXP-NNN / источник)
<Описание проблемы. Что произошло.>
<Решение. Как исправили или как избежать.>
<Общий паттерн. Когда это может повториться.>
```

2-4 строки. Группировать по категориям (ML Architecture, ML Methodology, Testing, etc.)

---

## Гипотеза в RESEARCH.md

```markdown
| H-NNN | <Гипотеза (SMART: конкретная, измеримая)> | ⬜ Не проверена | — | — | — |
```

Статусы: `⬜ Не проверена` → `🔬 Проверяется` → `✅ Подтверждена` / `❌ Опровергнута`

---

## ADR в BACKLOG.md

```markdown
- ADR-NNN: <Решение> — <контекст, рассмотренные альтернативы, последствия> [YYYY-MM-DD]
```

---

## Эксперимент (experiments/EXP-NNN.md)

```markdown
# EXP-NNN: <Название>

## Гипотеза
H-NNN: <текст гипотезы>

## Настройка
- Baseline: <описание baseline конфигурации>
- Treatment: <ОДНО изменение относительно baseline>
- Метрика: <что измеряем, как определяем успех>
- Горизонт: <N эпизодов, seeds>
- Конфигурация: <ключевые гиперпараметры>

## Результаты

| Метрика | Baseline | Treatment | Delta | p-value | Cohen's d |
|---------|----------|-----------|-------|---------|-----------|
| reward  |          |           |       |         |           |
| entropy |          |           |       |         |           |

## Выводы
- <основной finding>
- <что это значит для проекта>

## Следующие шаги
- <что делать дальше на основе результатов>

## Статус: ⬜ Pending / 🔬 Running / ✅ Done / ❌ Failed
```

Принцип: одно изменение за эксперимент (single-change policy).

---

## План (plans/YYYY-MM-DD_<type>_<topic>.md)

Types: `feature`, `fix`, `refactor`, `experiment`

```markdown
# План: <type> — <topic>

## Контекст

**Проблема:** <что промптило создание этого плана>

**Ожидаемый результат:** <что должно получиться>

**Связанные файлы:**
- <ссылки на код, спеки, эксперименты>

---

## Этапы

### Этап 1: <название>

**Что сделать:**
- <конкретные действия>

**Тестирование (TDD — тесты ПЕРЕД реализацией):**
- <unit тесты: что проверяем, edge cases>
- <integration тесты: какие компоненты вместе>

**DoD (Definition of Done):**
- [ ] <конкретный, измеримый критерий (SMART)>
- [ ] тесты проходят
- [ ] lint clean

**Правила кода:** SOLID, DRY, KISS, YAGNI, Clean Architecture

---

### Этап 2: <название>

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
| <риск> | H/M/L | <как предотвратить> |

## Gate (критерий успеха плана)

<Когда план считается выполненным целиком>
```

---

## Инициализация нового Memory Bank (/mb init)

Создаёт минимальную структуру:

```
.memory-bank/
├── STATUS.md       # Заголовок + "Текущая фаза: Начало"
├── plan.md         # Заголовок + "Текущий фокус: определить"
├── checklist.md    # Заголовок + пустой чеклист
├── RESEARCH.md     # Заголовок + пустая таблица гипотез
├── BACKLOG.md      # Заголовок + пустые секции
├── progress.md     # Заголовок
├── lessons.md      # Заголовок
├── experiments/    # Пустая директория
├── plans/          # Пустая директория
│   └── done/       # Пустая директория
├── notes/          # Пустая директория
└── reports/        # Пустая директория
```

---

## Drift checks (`scripts/mb-drift.sh`)

Deterministic проверки консистентности `.memory-bank/` без AI-вызовов. Используется `mb-doctor` шагом 0 — экономит токены когда банк уже чист.

### Использование

```bash
# На текущем проекте
bash ~/.claude/skills/memory-bank/scripts/mb-drift.sh .

# На другом проекте
bash ~/.claude/skills/memory-bank/scripts/mb-drift.sh /path/to/project
```

### Output (stdout — key=value)

```
drift_check_path=ok
drift_check_staleness=ok
drift_check_script_coverage=ok
drift_check_dependency=skip
drift_check_cross_file=ok
drift_check_index_sync=skip
drift_check_command=ok
drift_check_frontmatter=ok
drift_warnings=0
```

**Значения:** `ok` (нет проблем), `warn` (drift найден), `skip` (проверка неприменима — например `dependency=skip` если нет `pyproject.toml`/`package.json`/`go.mod`).

Диагностические сообщения — на stderr, префикс `[drift:<name>]`.

**Exit code:** 0 если `drift_warnings=0`, иначе 1 (подходит для pre-commit hook).

### 8 чекеров

| Имя | Что проверяет |
|-----|---------------|
| `path` | Ссылки `notes/X.md`, `plans/X.md`, `reports/X.md`, `experiments/X.md` в core-файлах существуют |
| `staleness` | `STATUS.md`/`plan.md`/`checklist.md`/`progress.md` не обновлялись >30 дней |
| `script_coverage` | `bash scripts/X.sh` references ведут на existing файлы (в проекте или в skill) |
| `dependency` | Python версия в `STATUS.md` совпадает с `pyproject.toml` (если есть) |
| `cross_file` | Числа вида "N bats green" консистентны между `STATUS.md`, `checklist.md`, `progress.md` |
| `index_sync` | `index.json` mtime свежее всех `notes/*.md` (иначе нужно переиндексировать) |
| `command` | `npm run X` / `make X` references ведут на existing scripts/targets |
| `frontmatter` | `notes/*.md` с `---` имеют закрывающий fence |

### Интеграция с `mb-doctor`

`mb-doctor` вызывает `mb-drift.sh` первым шагом:
- `drift_warnings=0` → отчёт "ok", LLM-анализ не нужен
- `drift_warnings>0` → читать warnings и запустить Шаги 1-4 агента (cross-reference проверки, Edit fixes)

Это даёт ~80% экономии токенов на стандартных случаях, когда банк чист.

### Pre-commit hook (optional)

```bash
# .git/hooks/pre-commit
#!/bin/bash
bash ~/.claude/skills/memory-bank/scripts/mb-drift.sh . || {
  echo "Memory Bank drift detected — run /mb doctor to fix"
  exit 1
}
```

---

## Custom metrics override (`.memory-bank/metrics.sh`)

Опциональный файл. Если существует — `mb-metrics.sh` вызовет его вместо auto-detect. Используй когда:
- проект имеет нестандартную структуру (monorepo, несколько языков в одном)
- нужны специфичные метрики (custom test runner, kubernetes readiness, ML reward и т.п.)
- auto-detect возвращает `stack=unknown`

Скрипт должен выводить `key=value` строки на stdout:

```bash
#!/usr/bin/env bash
# .memory-bank/metrics.sh — custom metrics для этого проекта.

set -euo pipefail

echo "stack=custom"                       # произвольная метка
echo "test_cmd=make test"                 # как запускать тесты
echo "lint_cmd=make lint"                 # как линтить
echo "src_count=$(find src -type f | wc -l | tr -d ' ')"

# Любые дополнительные метрики (будут переданы в MB Manager as-is):
echo "coverage=$(coverage report | tail -1 | awk '{print $4}')"
echo "reward_mean=$(jq '.mean' results.json)"
```

После создания — `chmod +x .memory-bank/metrics.sh`. Тестирование: `bash scripts/mb-metrics.sh` должен вернуть `source=override` вместо `source=auto`.
