# ~/.claude/commands/commit.md
---
description: Проверь staged изменения и сделай коммит
allowed-tools: [Bash, Read]
---
1. Выполни `git diff --staged`
2. Проверь что нет:
   - Debug-кода, fmt.Println, console.log
   - Закомментированного кода
   - TODO/FIXME/HACK
   - Захардкоженных секретов
3. Если нашёл проблемы — покажи и спроси продолжать ли
4. Сгенерируй commit message в формате Conventional Commits:
   - feat/fix/refactor/test/docs/chore
   - Scope в скобках если очевиден
   - Краткое описание на английском
5. Если передан $ARGUMENTS — используй как описание коммита
6. Выполни `git commit -m "<message>"`