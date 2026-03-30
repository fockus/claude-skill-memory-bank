---
description: Добавление structured logging, metrics, tracing в модуль
allowed-tools: [Read, Glob, Grep, Bash, Write]
---

# Observability: $ARGUMENTS

## 1. Анализ текущего состояния

```bash
# Логирование
grep -rn "log\.\|logger\.\|logging\.\|fmt\.Print\|console\.log\|print(" \
  --include="*.go" --include="*.py" --include="*.ts" . | head -30

# Метрики
grep -rn "prometheus\|metrics\|statsd\|datadog" . | head -20

# Tracing
grep -rn "opentelemetry\|jaeger\|zipkin\|trace\.\|span\." . | head -20

# Текущие зависимости
grep -E "zerolog|zap|slog|logrus|structlog|pino" go.mod package.json requirements.txt 2>/dev/null
```

## 2. Structured Logging

### Go (zerolog / slog)
- Замени `fmt.Println` / `log.Println` на structured logger
- Обязательные поля: timestamp, level, message, request_id, error (если есть)
- Уровни: DEBUG (dev), INFO (бизнес-события), WARN (recoverable), ERROR (failures)
- JSON формат для production

### Python (structlog)
- Замени `print()` / `logging.info()` на structured logger
- JSON формат для production, colored для dev

### Требования
- Логи НЕ содержат PII / secrets
- Каждый лог имеет correlation ID (request_id / trace_id)
- Error логи включают stack trace

## 3. Metrics (Prometheus)

Добавь метрики:
- `http_requests_total` — counter by method, path, status
- `http_request_duration_seconds` — histogram by method, path
- Бизнес-метрики: registrations, orders, payments (counter)
- Go runtime: goroutines, memory (автоматически через promhttp)

Требования:
- Bounded cardinality (НЕ user_id / email в labels)
- Middleware/interceptor подход (не inline в handlers)

## 4. Tracing (OpenTelemetry)

Добавь spans:
- HTTP handler (автоматически через middleware)
- DB queries
- External API calls
- Ключевые бизнес-операции

Требования:
- Context propagation через весь стек
- Sampling для production (не 100%)
- Trace ID в логах для корреляции

## 5. Проверка

- Нет PII/secrets в логах
- Metrics имеют bounded cardinality
- Traces имеют sampling
- Всё подключается через middleware (не inline в бизнес-логику)
- Тесты не ломаются от добавления observability

Если есть `./.memory-bank/` — заметка в `notes/`.
