---
description: Управление API контрактами — OpenAPI, gRPC, breaking changes detection
allowed-tools: [Read, Glob, Grep, Bash, Write]
---

# API Contract: $ARGUMENTS

## 1. Определение типа API

```bash
# OpenAPI / Swagger
find . -name "*.yaml" -o -name "*.yml" | xargs grep -l "openapi\|swagger" 2>/dev/null
find . -name "openapi*" -o -name "swagger*" 2>/dev/null

# gRPC / Protobuf
find . -name "*.proto" 2>/dev/null

# GraphQL
find . -name "*.graphql" -o -name "*.gql" 2>/dev/null

# Go handlers
grep -rn "func.*Handler\|func.*http\.\|r\.GET\|r\.POST\|r\.PUT\|r\.DELETE" --include="*.go" . | head -30
```

## 2. Действие

В зависимости от $ARGUMENTS:

### generate — Генерация спецификации
- Изучи все endpoints / handlers / routes
- Сгенерируй OpenAPI 3.0 спецификацию
- Включи: paths, schemas, request/response bodies, error codes, auth

### check — Breaking Changes Detection
- Сравни текущую спецификацию с последней зафиксированной
- Breaking changes:
  - Удалённые endpoints
  - Изменённые типы полей
  - Новые required поля (без default)
  - Удалённые response fields
  - Изменённые HTTP methods / status codes

### test — Contract Tests
- Сгенерируй тесты на основе спецификации
- Проверь что API соответствует контракту
- Проверь error responses и edge cases

## 3. Валидация

```bash
# OpenAPI lint (если установлен)
npx @stoplight/spectral-cli lint openapi.yaml 2>/dev/null

# Protobuf lint
buf lint 2>/dev/null

# Contract tests
go test ./api/... -run TestContract 2>/dev/null
```

## 4. Результат

Сохрани/обнови спецификацию в `./docs/api/` или `./api/`.
Если есть `./.memory-bank/` — заметка в `notes/`.
