# ~/.claude/commands/pr.md
---
description: Создай PR из текущей ветки
allowed-tools: [Bash, Read]
---
1. Выполни `git diff main --stat` — покажи что изменилось
2. Прочитай `./.memory-bank/checklist.md` и последний план если есть
3. Сгенерируй описание PR:
   - Заголовок в формате Conventional Commits
   - Секция "Что сделано" — список изменений
   - Секция "Как тестировать" — шаги для ревьюера
   - Секция "Связанные issues" — если есть
4. Выполни `gh pr create --title "<title>" --body "<body>"`
5. Если передан $ARGUMENTS — используй как заголовок