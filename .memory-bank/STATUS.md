# claude-skill-memory-bank: Статус проекта

## Текущая фаза
**Phase: v2.0.0 released.** Все 10 этапов рефактора завершены. План перенесён в `plans/done/`. Skill готов к релизу.

Three-in-one skill для Claude Code: (1) Long-term project memory через `.memory-bank/`, (2) global dev rules (TDD, Clean Architecture для backend, FSD для frontend, Mobile UDF+Clean для iOS/Android, SOLID, Testing Trophy), (3) dev toolkit из 18 команд.

## Ключевые метрики
- Shell-скрипты: **11** (`_lib.sh`, `mb-metrics.sh`, `mb-plan-sync.sh`, `mb-plan-done.sh`, `mb-upgrade.sh`, `mb-context.sh`, `mb-search.sh`, `mb-note.sh`, `mb-plan.sh`, `mb-index.sh`, 2 хука)
- Python-скрипты: **2** (`merge-hooks.py`, `mb-index-json.py`)
- Агенты: 4 (`mb-manager`, `mb-doctor`, `plan-verifier`, `mb-codebase-mapper`)
- Команды: **18** в `commands/`
- Bats tests: **148/148 green** (117 unit + 15 e2e + 11 hooks + 5 search-tag)
- Python tests: **35/35 green** (16 merge-hooks + 19 index-json). **TOTAL coverage 94%**
- Shellcheck warnings: **0**
- Ruff: **0 errors**
- CI: **`.github/workflows/test.yml`** — matrix `[ubuntu-latest, macos-latest]` × (bats + e2e + pytest) + lint job (shellcheck + ruff)
- Fixtures: 12 стеков (python, go, rust, node, java, kotlin, swift, cpp, ruby, php, csharp, elixir + multi + unknown)
- Hardcoded `pytest`/`ruff`/`taskloom` в operational code: **0**
- Orphan-агенты: **0**
- `Task(` legacy в skill-файлах: **0**
- Rules coverage: backend (Clean Architecture), frontend (FSD), mobile (iOS/Android UDF+Clean)
- Consistency-chain: plan↔checklist↔plan.md автоматизировано
- **VERSION**: **2.0.0**
- SKILL.md: 110 строк (порог ≤150)
- Docs: `CHANGELOG.md` (v1→v2), `docs/MIGRATION-v1-v2.md`

## Roadmap

### ✅ Завершено
- **Аудит skill v1**: выявлено 36 проблем, сгруппировано по критичности
- **План рефактора v2**: 10 этапов с DoD SMART, TDD, рисками, Gate
- **Этап 0: Dogfood init** — коммит `637dd84`
- **Этап 1: DRY + language detection** — `_lib.sh`, коммит `722fbc5`
- **Этап 2: Language-agnostic metrics** — коммит `4695a1f`
- **Этап 2.1: Java/Kotlin/Swift/C++** — коммит `69f9422`
- **Этап 2.2: Ruby/PHP/C#/Elixir** — коммит `4ad08aa`
- **Этап 3: mb-codebase-mapper** — коммит `cd65d0a`
- **Этап 3.5: /mb upgrade** — коммит `5776be0`
- **Этап 4: Автоматизация consistency-chain** — коммит `5bd10c8`
- **Этап 5: Ecosystem integration** — коммит `2bd7c8d`
- **Этап 6: Tests + CI** — коммит `417e8d4`
- **Этап 7: Hooks fixes** — коммит `9cb1dd1`
- **Этап 8: index.json прагматично** — коммит `595b633`
- **Этап 9: Финализация** — CHANGELOG + MIGRATION + SKILL.md ≤150 + VERSION 2.0.0 + dogfood `mb-plan-done` на самом плане

### ⬜ v3 backlog (не входит в scope v2)
- sqlite-vec для реального semantic search
- i18n error-сообщений
- Native memory bridge (программная синхронизация с Claude Code auto memory)
- Опциональный вынос 10 dev-команд в отдельный plugin

## Gate v2 — all criteria passed ✅

1. ✅ **Language coverage**: 12 стеков (было: 4 целевых; покрытие превышает план)
2. ✅ **Cross-platform**: CI matrix `[macos-latest, ubuntu-latest]`
3. ✅ **Ecosystem**: 0 `Task(` legacy, coexistence documented, `Agent(...)` везде
4. ✅ **DRY + tested**: `_lib.sh` в 5+ скриптах; Python coverage 94% (порог 85%); 0 shellcheck warnings
5. ✅ **UX**: `/mb init [--minimal|--full]`; `mb-codebase-mapper` генерирует 4 MD; `/mb context` integrated summary
6. ✅ **Dogfooding**: skill использует `.memory-bank/` в своём репозитории; план перенесён в `plans/done/` через `mb-plan-done.sh` (который сам реализован в Этапе 4)
7. ✅ **Versioning**: CHANGELOG v1→v2, migration guide, VERSION 2.0.0