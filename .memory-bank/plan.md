# claude-skill-memory-bank — План

## Текущий фокус

**v2.0.0 released.** Skill language-agnostic, tested, CI-covered, интегрирован с экосистемой Claude Code. Three-in-one: Memory Bank + RULES + dev toolkit.

## Active plan

<!-- mb-active-plan -->
<!-- /mb-active-plan -->

Нет активного плана. Завершённые планы в `plans/done/`.

## Ближайшие шаги

1. Мониторить CI после push на GitHub (первый запуск workflow)
2. Собрать feedback от пользователей после релиза v2.0.0
3. Решение по v3 backlog-идеям (sqlite-vec, i18n, native memory bridge code)

## Отложено (v3+ backlog)

- **sqlite-vec** для реального semantic search — вместо текущего простого frontmatter-index
- **i18n** error-сообщений — сейчас всё на русском
- **Native memory bridge** — программная синхронизация `.memory-bank/` и auto memory (сейчас только документация coexistence)
- **Отдельный plugin** `memory-bank-dev-commands` — вынос 10 dev-команд в отдельный плагин (если пользователи потребуют модульность)
