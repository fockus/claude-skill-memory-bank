# Memory Bank — metadata protocol

Детальное описание YAML frontmatter в `notes/` и структуры `index.json`.

---

## Frontmatter формат

Все заметки в `notes/` создаются с YAML frontmatter для семантического поиска и targeted recall.

```yaml
---
type: lesson | note | decision | pattern
tags: []
related_features: []
sprint: null
importance: high | medium | low
created: YYYY-MM-DD
---
```

### Правила

1. **Все новые notes/** получают YAML frontmatter при создании (MB Manager генерирует автоматически).
2. **Tags** извлекаются LLM из содержимого заметки: 3-7 ключевых технических терминов, lowercase, singular.
3. **Importance**:
   - `high` — patterns, decisions, critical architectural insights
   - `medium` — general notes, knowledge
   - `low` — minor observations, одноразовые фиксы
4. **Шаблон**: `references/templates.md`.
5. **Старые заметки** (без frontmatter) продолжают работать — `index.json` обрабатывает их с default `type: note`, `tags: []`.

---

## Index Protocol

Memory Bank использует `index.json` для быстрого поиска без чтения всех файлов.

### Формат `{mb_path}/index.json`

```json
{
  "notes": [
    {
      "path": "notes/2026-03-29_14-30_topic.md",
      "type": "pattern",
      "tags": ["sqlite-vec", "embedding"],
      "importance": "high",
      "summary": "Local semantic search pattern via sqlite-vec"
    }
  ],
  "lessons": [
    {
      "id": "L-001",
      "title": "Avoid mocking more than 5 dependencies"
    }
  ],
  "generated_at": "2026-04-19T12:00:00Z"
}
```

### Regeneration

- Пересоздаётся при `/mb done` (через MB Manager `action: actualize` → вызов `scripts/mb-index-json.py`).
- Также пересоздаётся автоматически при `mb-search --tag <tag>`, если отсутствует.
- Вручную: `python3 ~/.claude/skills/memory-bank/scripts/mb-index-json.py <mb_path>`.

### Usage

Agent читает `index.json` → фильтрует по `tags`/`importance` → читает только релевантные файлы.

### Fallback

- `PyYAML` не установлен → простой fallback-парсер в `mb-index-json.py` (понимает `key: value` и `key: [a, b]`).
- `index.json` отсутствует → `mb-search` работает через grep, `mb-search --tag` возвращает error с hint.

---

## Ключевые правила Memory Bank

1. **Core files = истина о проекте**. `STATUS.md`, `plan.md`, `checklist.md` — всегда актуальны.
2. **`progress.md` = APPEND-ONLY**. Никогда не удалять и не редактировать старые записи.
3. **Нумерация сквозная**: H-NNN (гипотезы), EXP-NNN (эксперименты), ADR-NNN (решения), L-NNN (уроки).
4. **`notes/` = знания, не хронология**. 5-15 строк. Выводы, паттерны, переиспользуемые решения.
5. **Checklist**: ✅ = выполнено, ⬜ = не выполнено. Обновлять каждую сессию.
6. **Не вставляй логи, stacktraces, большие блоки кода**. Только дистиллированные заметки.
7. **ML эксперименты**: гипотеза (SMART) → baseline → одно изменение → run → результат (p-value, Cohen's d).
8. **Архитектурные решения** → ADR в `BACKLOG.md` (контекст → решение → альтернативы → последствия).
