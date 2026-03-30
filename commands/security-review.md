---
description: Сканирование кода на security vulnerabilities (OWASP, secrets, dependencies)
allowed-tools: [Read, Glob, Grep, Bash]
---

# Security Review: $ARGUMENTS

## 1. Scope

- Если $ARGUMENTS указан — анализируй указанный модуль/директорию
- Если не указан — анализируй все изменённые файлы (`git diff --name-only`)

## 2. Автоматический анализ

Определи стек и запусти подходящие сканеры:

### Go
```bash
gosec -quiet ./...
golangci-lint run --enable=gosec,errcheck,govet
```

### Python
```bash
bandit -r . -f txt -ll
safety check 2>/dev/null
```

### Node.js
```bash
npm audit 2>/dev/null
```

### Поиск секретов
```bash
grep -rn --include="*.go" --include="*.py" --include="*.js" --include="*.ts" --include="*.yaml" --include="*.yml" --include="*.env*" \
  -E "(password|secret|api_key|token|AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{36}|sk_live_)" .
```

## 3. Ручной анализ

Прочитай каждый файл в scope и проверь:

- **Injection:** SQL, command, XSS, LDAP, template injection
- **Authentication:** слабые пароли, отсутствие rate limiting, хранение credentials
- **Authorization:** отсутствие проверок прав, IDOR, privilege escalation
- **Data Exposure:** логирование секретов, лишние данные в API responses, stack traces в production
- **Configuration:** debug mode, CORS *, отключённый HTTPS, default credentials
- **Dependencies:** известные CVE
- **Cryptography:** MD5/SHA1 для паролей, hardcoded keys, отсутствие salt

## 4. OWASP Top 10 Checklist

- [ ] A01 — Broken Access Control
- [ ] A02 — Cryptographic Failures
- [ ] A03 — Injection
- [ ] A04 — Insecure Design
- [ ] A05 — Security Misconfiguration
- [ ] A06 — Vulnerable and Outdated Components
- [ ] A07 — Identification and Authentication Failures
- [ ] A08 — Software and Data Integrity Failures
- [ ] A09 — Security Logging and Monitoring Failures
- [ ] A10 — Server-Side Request Forgery

## 5. Отчёт

```markdown
# Security Review Report
Дата: YYYY-MM-DD HH:MM
Scope: <что проверялось>

## Критичное (блокирует релиз)
- [файл:строка] <уязвимость> — <рекомендация>

## Высокий риск
- [файл:строка] <описание> — <рекомендация>

## Средний риск
- [файл:строка] <описание> — <рекомендация>

## Низкий риск
- [файл:строка] <описание> — <рекомендация>

## Dependencies
- <пакет@версия>: <CVE>

## Итог
<1-3 предложения: общая оценка, главные риски>
```

Если существует `./.memory-bank/` — сохрани в `./.memory-bank/reports/YYYY-MM-DD_security-review.md`.
