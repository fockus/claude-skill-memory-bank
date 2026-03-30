---
name: mb:setup-project
description: "Инициализация проекта: .memory-bank/ + RULES.md + CLAUDE.md с автодетектом стека"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Agent
  - AskUserQuestion
---

<objective>
Полная настройка проекта для работы с Memory Bank и RULES:
1. Создаёт .memory-bank/ (если нет)
2. Копирует RULES.md в .memory-bank/
3. Сканирует проект → автодетект стека
4. Генерирует CLAUDE.md в корне проекта
5. Предлагает .planning/ → .memory-bank/.planning/ symlink
</objective>

<context>
$ARGUMENTS
</context>

<process>

## Step 1: Init Memory Bank

Если `.memory-bank/` не существует → вызови `/mb init`.
Если существует → `[MEMORY BANK: ACTIVE]`, продолжай.

## Step 2: Copy RULES

1. Проверь `~/.claude/RULES.md` существует
2. Скопируй → `.memory-bank/RULES.md`
3. Если `.memory-bank/RULES.md` уже есть:
   - Сравни с глобальным: `diff ~/.claude/RULES.md .memory-bank/RULES.md`
   - Если различаются → спроси: "Обновить до глобальной версии? (y/n)"

## Step 3: Scan Project

Автоматически определи:

**Язык и runtime:**
```bash
# Python
[ -f pyproject.toml ] && echo "python" && python3 -c "
import tomllib
with open('pyproject.toml','rb') as f: d=tomllib.load(f)
print('name:', d.get('project',{}).get('name','?'))
print('python:', d.get('project',{}).get('requires-python','?'))
" 2>/dev/null

# Node/TypeScript
[ -f package.json ] && echo "node/typescript" && cat package.json | python3 -c "
import json,sys; d=json.load(sys.stdin)
print('name:', d.get('name','?'))
print('deps:', ', '.join(list(d.get('dependencies',{}).keys())[:10]))
" 2>/dev/null

# Go
[ -f go.mod ] && echo "go" && head -3 go.mod

# Rust
[ -f Cargo.toml ] && echo "rust" && head -5 Cargo.toml
```

**Фреймворки:**
- Python: FastAPI, Django, Flask (grep imports)
- Node: Next.js, Express, Nest (package.json deps)
- Go: gin, echo, fiber (go.mod)

**Структура:**
```bash
# Source dirs
ls -d src/ lib/ app/ cmd/ internal/ pkg/ 2>/dev/null
# Test dirs
ls -d tests/ test/ __tests__/ spec/ 2>/dev/null
# Config files
ls pyproject.toml package.json go.mod Cargo.toml Makefile Dockerfile docker-compose.yml .github/ 2>/dev/null
```

**Инструменты:**
- Linter: ruff, eslint, golangci-lint
- Formatter: black, prettier, gofmt
- Type checker: mypy, pyright, tsc
- Test runner: pytest, jest, vitest, go test
- Package manager: uv, npm, pnpm, yarn

Сохрани результаты в переменные: `{LANGUAGE}`, `{FRAMEWORK}`, `{STRUCTURE}`, `{TOOLS}`.

## Step 4: Generate CLAUDE.md

Используй шаблон из `~/.claude/skills/memory-bank/references/claude-md-template.md`.

Сгенерируй `CLAUDE.md` в корне проекта:

```markdown
## Project

**{project_name}**

{краткое описание — из pyproject.toml/package.json или спросить пользователя}

### Constraints

- **Tech stack**: {LANGUAGE} {version}, {key_deps}
- **Testing**: 85%+ overall, 95%+ core/business coverage. TDD mandatory.
- **Architecture**: SOLID, KISS, DRY, YAGNI, Clean Architecture, DDD

## Technology Stack

## Languages
- {LANGUAGE} {version} — all application source code in `{src_dir}/`

## Runtime
- {runtime_info}
- {package_manager} — primary manager

## Frameworks
- {FRAMEWORK}
- {test_framework} — test runner

## Key Dependencies
{top 10 dependencies}

## Configuration
- {config files detected}

## Conventions

## Naming Patterns
{detected from existing code — snake_case vs camelCase, etc.}

## Code Style
- Tool: {linter}
- Line length: {detected}
- Target: {language_version}

## Architecture

## Pattern Overview
- All cross-layer dependencies point inward: Infrastructure → Application → Domain
- Domain layer contains zero external dependencies

## Rules

Подробные правила: `~/.claude/RULES.md` + `.memory-bank/RULES.md`

### Критические правила (всегда соблюдать)

> **Contract-First** — Protocol/ABC → contract-тесты → реализация
> **TDD** — сначала тесты, потом код
> **Clean Architecture** — Infrastructure → Application → Domain (никогда обратно)
> **SOLID пороги** — SRP: >300 строк = разделить. ISP: Interface ≤5 методов
> **Без placeholder'ов** — никаких TODO, `...`, псевдокода
> **Coverage** — общий 85%+, core/business 95%+

## Memory Bank

**Если `./.memory-bank/` существует → `[MEMORY BANK: ACTIVE]`.**

**Команда:** `/mb`. **Workflow:** start → work → verify → done.

### Ключевые файлы

| Файл | Назначение |
|------|-----------|
| `STATUS.md` | Где мы, roadmap, метрики |
| `checklist.md` | Задачи ✅/⬜ |
| `plan.md` | Приоритеты, направление |
| `RULES.md` | Правила проекта |
```

**Покажи результат пользователю перед записью.**
Спроси: "Записать CLAUDE.md? Нужно что-то добавить/изменить?"

## Step 5: Planning directory

Если `.planning/` существует и `.memory-bank/.planning/` не существует:
```
Предлагаю перенести .planning/ внутрь .memory-bank/:
  mv .planning .memory-bank/.planning
  ln -s .memory-bank/.planning .planning

Это объединит все артефакты проекта в одной директории.
Symlink сохранит совместимость с GSD.

Сделать? (y/n)
```

Если пользователь согласен → выполни. Если нет → оставить как есть.

## Step 6: Commit

```bash
git add CLAUDE.md .memory-bank/
git commit -m "chore: setup project with Memory Bank and CLAUDE.md

- Generated CLAUDE.md with auto-detected stack
- Initialized .memory-bank/ with RULES.md
- Project ready for /build:* workflow

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

</process>

<output>
Выведи итог:
- CLAUDE.md: создан/обновлён
- .memory-bank/: инициализирован
- RULES.md: скопирован
- Detected stack: {language}, {framework}, {tools}
- Предложи следующий шаг: `/build:init` или `/mb start`
</output>
