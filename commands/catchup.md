# ~/.claude/commands/catchup.md
---
description: Загрузи текущий контекст после очистки
allowed-tools: [Bash, Read]
---
1. Прочитай `~/.claude/CLAUDE.md`
2. Если существует `./.memory-bank/` — прочитай `checklist.md` + `plan.md` + последнюю заметку из `notes/`
3. Выполни `git diff` и `git diff --staged` — покажи что в работе
4. Выполни `git log --oneline -5` — покажи последние коммиты
5. Резюмируй в 3-5 предложениях: что сделано, что в процессе, что дальше