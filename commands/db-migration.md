---
description: Создание и управление миграциями БД (golang-migrate, Alembic, Prisma)
allowed-tools: [Read, Glob, Grep, Bash, Write]
---

# Database Migration: $ARGUMENTS

## 1. Определение инструментов

```bash
# golang-migrate
ls migrations/ db/migrations/ 2>/dev/null
grep -r "golang-migrate\|goose\|atlas" go.mod 2>/dev/null

# Alembic (Python)
ls alembic/ 2>/dev/null; cat alembic.ini 2>/dev/null

# Prisma (Node.js)
cat prisma/schema.prisma 2>/dev/null

# SQL файлы
find . -name "*.sql" -path "*/migrat*" 2>/dev/null | head -20
```

## 2. Создание миграции

### Формат имени
`YYYYMMDDHHMMSS_<описание>.up.sql` / `.down.sql`

### Требования
- Каждая миграция имеет up И down
- down полностью откатывает up
- Destructive операции (DROP TABLE, DROP COLUMN) — только после подтверждения
- Данные мигрируются отдельно от схемы
- Индексы создаются CONCURRENTLY если поддерживается

### Анализ
1. Прочитай существующие миграции — пойми текущую схему
2. Определи что нужно изменить ($ARGUMENTS)
3. Проверь нет ли конфликтов с последними миграциями
4. Покажи план изменений и спроси подтверждение

## 3. Генерация

Сгенерируй up и down миграции. Проверь:
- Идемпотентность: `IF NOT EXISTS`, `IF EXISTS`
- Backwards compatibility: старый код работает с новой схемой
- Rollback safety: down не теряет данные без предупреждения

## 4. Тестирование

```bash
# Применить up
migrate -path migrations -database "$DATABASE_URL" up

# Проверить схему
# Применить down
migrate -path migrations -database "$DATABASE_URL" down 1

# Применить up снова (идемпотентность)
migrate -path migrations -database "$DATABASE_URL" up
```

## 5. Memory Bank

Если существует `./.memory-bank/` — заметка в `notes/` с описанием изменений схемы.
