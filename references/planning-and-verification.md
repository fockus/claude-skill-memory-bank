# Memory Bank — planning and verification

Правила создания планов и процесс верификации через Plan Verifier.

---

## Правила создания планов

Создание плана — **главный агент** (не MB Manager).

### Шаги

1. Создай файл: `bash ~/.claude/skills/memory-bank/scripts/mb-plan.sh <type> "<topic>"`. Типы: `feature`, `fix`, `refactor`, `experiment`.
2. Заполни секции:
   - **Контекст**: проблема, что промптило, ожидаемый результат.
   - **Этапы**: каждый с DoD по SMART (конкретный, измеримый, достижимый, реалистичный, с временными рамками).
   - **Тестирование**: unit + integration тесты ПЕРЕД реализацией (TDD).
   - **Каждый этап**: что тестировать, какие edge cases, lint requirements.
   - **Правила кода**: SOLID, DRY, KISS, YAGNI, Clean Architecture/FSD/Mobile — по `RULES.md`.
   - **Риски**: вероятность (H/M/L), mitigation.
   - **Gate**: критерий успеха плана целиком.
3. Этапы атомарны и упорядочены по зависимостям.
4. Нет placeholder'ов — каждый шаг конкретен.
5. Каждый `assert` в тестах проверяет бизнес-требование или edge case.

### Маркеры этапов

Шаблон `mb-plan.sh` автоматически добавляет `<!-- mb-stage:N -->` перед `### Этап N: <name>`. Эти маркеры используются `mb-plan-sync.sh` и `mb-plan-done.sh` для автоматической синхронизации с `checklist.md`, `plan.md`.

### Консистентность — ОБЯЗАТЕЛЬНО при создании плана

После создания плана запусти:

```bash
bash ~/.claude/skills/memory-bank/scripts/mb-plan-sync.sh <путь к плану>
```

Скрипт идемпотентно:
- добавит отсутствующие секции `## Этап N: <name>` в `checklist.md`
- обновит блок `<!-- mb-active-plan -->` в `plan.md`

### Цепочка source of truth

```
plan.md (Active plan → ссылка) → plans/<файл>.md (задачи, DoD) → checklist.md (трекинг) → STATUS.md (фаза)
```

**При завершении плана:**

```bash
bash ~/.claude/skills/memory-bank/scripts/mb-plan-done.sh <путь к плану>
```

Скрипт переместит файл в `plans/done/`, закроет `⬜ → ✅`, очистит Active plan блок.

---

## Plan Verifier — верификация планов

Plan Verifier — subagent на Sonnet, который проверяет соответствие кода плану. Prompt: `agents/plan-verifier.md`.

### Когда запускать

**ОБЯЗАТЕЛЬНО** перед закрытием плана (`/mb done` при работе по плану):

1. Вызови `/mb verify`.
2. Plan Verifier перечитает план, проверит `git diff`, найдёт расхождения.
3. Исправь все CRITICAL проблемы.
4. WARNING — на усмотрение (спроси пользователя).
5. Только после этого — `/mb done`.

### Формат вызова

```
Agent(
  subagent_type="general-purpose",
  model="sonnet",
  description="Plan Verifier: проверка плана",
  prompt="<содержание agents/plan-verifier.md>\n\nФайл плана: <путь>\n\nКонтекст: <что сделано>"
)
```

### Категории проблем

| Категория | Что значит | Действие |
|-----------|-----------|----------|
| CRITICAL | Этап не реализован, DoD не выполнен, тесты отсутствуют | Исправить обязательно |
| WARNING | Частичное покрытие, отклонение от плана | Спросить пользователя |
| INFO | Дополнительная работа не из плана | Принять к сведению |
