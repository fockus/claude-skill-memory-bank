# ~/.claude/commands/changelog.md
---
description: Сгенерируй changelog из коммитов
allowed-tools: [Bash, Read]
---
1. Определи последний тег: `git describe --tags --abbrev=0 2>/dev/null || echo "начало"`
2. Собери коммиты с последнего тега: `git log <tag>..HEAD --pretty=format:"%h %s" --no-merges`
3. Сгруппируй по типам: feat, fix, refactor, test, docs, chore
4. Сгенерируй CHANGELOG запись в формате Keep a Changelog
5. Если $ARGUMENTS — используй как версию, иначе предложи по semver