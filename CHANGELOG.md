# Changelog

Все значимые изменения документируются здесь. Формат — [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), версионирование — [SemVer](https://semver.org/spec/v2.0.0.html).

## [2.0.0] — 2026-04-19

Крупный рефакторинг: skill становится language-agnostic, tested, CI-covered, integrated с экосистемой Claude Code. Три концепта под одной крышей: **Memory Bank + RULES + dev toolkit**.

### Added

- **Language detection (12 стеков)**: Python, Go, Rust, Node/TypeScript, Java, Kotlin, Swift, C/C++, Ruby, PHP, C#, Elixir. `scripts/mb-metrics.sh` выдаёт key=value метрики для любого из них.
- **Override для проектных метрик**: `.memory-bank/metrics.sh` (приоритет 1 над auto-detect).
- **`scripts/_lib.sh`** — общие утилиты (workspace resolver, slug, collision-safe filename, detect_stack/test/lint/src_glob). 7 функций, 36 bats-тестов.
- **`scripts/mb-plan-sync.sh`** и **`scripts/mb-plan-done.sh`** — автоматизация консистентности plan↔checklist↔plan.md через маркеры `<!-- mb-stage:N -->`.
- **`scripts/mb-upgrade.sh`** — `/mb upgrade` для самообновления skill из GitHub (git fetch → prompt → ff-only pull + re-install).
- **`scripts/mb-index-json.py`** — прагматичный index для `notes/` (frontmatter) + `lessons.md` (H3 маркеры). Atomic write. PyYAML opt-in с fallback.
- **`mb-search --tag <tag>`** — фильтрация по тегам через `index.json`.
- **`/mb init [--minimal|--full]`** — единая инициализация. `--full` (default) = `.memory-bank/` + `RULES.md` copy + auto-detect стека + `CLAUDE.md` + optional `.planning/` symlink.
- **`/mb map [focus]`** — сканирование кодовой базы и генерация `.memory-bank/codebase/{STACK,ARCHITECTURE,CONVENTIONS,CONCERNS}.md`.
- **`/mb context --deep`** — полный codebase-контент (default = 1-line summary).
- **Правила Frontend (FSD)** и **Mobile (iOS + Android)** в `rules/RULES.md` и `rules/CLAUDE-GLOBAL.md`.
- **`MB_ALLOW_NO_VERIFY=1`** — bypass для `--no-verify` в `block-dangerous.sh`.
- **Log rotation** для `file-change-log.sh`: >10 MB → `.log.1 → .log.2 → .log.3`.
- **GitHub Actions** `.github/workflows/test.yml`: matrix `[ubuntu-latest, macos-latest]` × (bats + e2e + pytest) + lint job (shellcheck + ruff).
- **148 bats-тестов** (unit + e2e + hooks + search-tag), **35 pytest-тестов**, **94% total coverage**.

### Changed

- **`codebase-mapper` → `mb-codebase-mapper`** (MB-native): output path `.planning/codebase/` → `.memory-bank/codebase/`; 770 строк → 316 (−59%); 6 шаблонов → 4 (STACK, ARCHITECTURE, CONVENTIONS, CONCERNS), каждый ≤70 строк.
- **`/mb update` и `mb-doctor`** больше не хардкодят `pytest`/`ruff`/`src/taskloom/` — используют `mb-metrics.sh`.
- **`SKILL.md` frontmatter** — `user-invocable: false` (невалидное поле) заменено на `name: memory-bank` с описанием three-in-one concept.
- **`Task(...)` → `Agent(subagent_type=...)`** во всех skill-файлах. Grep-проверка: 0 вхождений `Task(`.
- **`mb-doctor`** чинит рассинхроны приоритетно через `mb-plan-sync.sh`/`mb-plan-done.sh`, Edit — только для семантических проблем.
- **`install.sh`** — всегда пишет `# [MEMORY-BANK-SKILL]` маркер при создании нового `CLAUDE.md` (раньше — только при merge в существующий).
- **`mb-manager actualize`** — вызывает `mb-index-json.py` вместо ручного Write на `index.json`.
- **`file-change-log.sh`** — убран `pass\s*$` из placeholder-regex (false-positive); placeholder-поиск теперь вне Python docstrings.
- **`install.sh` banner**: `19 dev commands` → `18 dev commands` (после слияния init-команд).

### Deprecated

- (нет — все deprecations полные в этом релизе; см. Removed)

### Removed

- **`/mb:setup-project`** — слит в `/mb init --full`. Команда `commands/setup-project.md` удалена.
- **Orphan-агент `codebase-mapper`** — заменён на `mb-codebase-mapper`.
- **Хардкод `pytest -q` / `ruff check src/`** в `commands/mb.md` и `agents/mb-doctor.md`.
- **Все `Task(...)` вызовы** в skill-файлах (осталось 0).

### Fixed

- **E2E-found bug #1**: `install.sh` не добавлял маркер `[MEMORY-BANK-SKILL]` при создании **нового** `CLAUDE.md`. Результат: `uninstall.sh` не находил секцию для очистки.
- **E2E-found bug #2**: `uninstall.sh` использовал GNU-only флаг `realpath -m`. На macOS BSD realpath падал. Fix: манифест хранит абсолютные пути, `realpath` не нужен.
- **Node src_glob**: brace-pattern `*.{ts,tsx,js,jsx}` заменён на space-separated для portable grep.
- **mb-note.sh**: коллизия имени (две заметки в одну минуту) теперь → `_2/_3` суффикс (было: `exit 1`).
- **file-change-log false-positives**: bare `pass` в Python, TODO внутри docstring.
- **shellcheck SC1003** в awk-блоке hook'а — переписан через `index()` без nested single-quote escapes.

### Security

- **`block-dangerous.sh`** обновлён с `MB_ALLOW_NO_VERIFY=1` explicit-opt-in override — раньше `--no-verify` блокировался наглухо без safe-escape.
- **secrets-detection** в `file-change-log.sh` продолжает работать (`password|secret|api_key|token|private_key` в source-коде).

### Infrastructure

- **Dogfooding**: сам skill использует `.memory-bank/` в своём репозитории. План рефактора v2 лежит в `.memory-bank/plans/`, сессии закрываются через `/mb done`.
- **VERSION marker**: `2.0.0-dev` → `2.0.0` пишется install.sh в `~/.claude/skills/memory-bank/VERSION`.
- **CI-зелёный** на macOS + Ubuntu, 0 shellcheck warnings, ruff all passed.

---

## [1.0.0] — 2025-10-XX (pre-refactor baseline)

- Initial Memory Bank skill: `.memory-bank/` structure, `/mb` roadmap-команда, 4 агента, 2 hooks, 19 commands.
- Python-first: хардкод `pytest`, `ruff`, `src/taskloom/`.
- Orphan-артефакты от GSD: `codebase-mapper`, `.planning/`.
- 0 автоматических тестов.

[2.0.0]: https://github.com/fockus/claude-skill-memory-bank/releases/tag/v2.0.0
[1.0.0]: https://github.com/fockus/claude-skill-memory-bank/releases/tag/v1.0.0
