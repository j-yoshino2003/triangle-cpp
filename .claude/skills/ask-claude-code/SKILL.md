---
name: ask-claude-code
description: Answers questions about Claude Code itself — hooks, skills, subagents, MCP servers, settings, permissions, the Agent SDK, and the Claude API — by delegating research to the built-in claude-code-guide agent (which reads the official docs) and reporting back in Japanese. Trigger it with questions like "Can Claude Code do X?" or "What does this setting mean?"
---

# ask-claude-code

> Japanese reference translation: `docs/ja-JP/skills/ask-claude-code.md`.

## Purpose

Take a question about Claude Code's own behavior, configuration, or extension points, have the
**built-in `claude-code-guide` agent** (restricted to reading the official documentation) research
it, and return an evidence-backed answer in Japanese.

Questions in scope:

- Whether a feature exists and how to use it ("Can a hook do X?", "How do I define a subagent?")
- What a setting means and how to write it (`settings.json` / `settings.local.json` / permissions / environment variables)
- Slash commands and keyboard shortcuts
- Connecting and managing MCP servers
- Using the Claude Agent SDK / Claude API

## User Input

The question is passed as an argument.

### Argument check

If the question is empty, print the following and **stop**:

```
エラー: Claude Code について調べたい質問を記述してください。

使い方:
  /ask-claude-code <質問>

例:
  /ask-claude-code PreToolUse フックで特定のコマンドだけブロックできる?
  /ask-claude-code settings.local.json と settings.json の優先順位は?
```

## Workflow

1. **Dispatch the agent**: launch the Agent tool with `subagent_type: "claude-code-guide"` and pass
   the user's question through unchanged.
   - A Japanese question may be passed as-is (keep technical terms and setting key names in their
     original form).
   - When project-specific context matters to the answer (this harness's layout, the local vendor
     plugins, and so on), append it to the question as supplementary notes.
2. **Report back**: summarize and organize the agent's answer for the user in Japanese.
   - Show settings and command examples in code blocks.
   - Include the URLs of any documentation the agent cited.
3. **Handling uncertainty**: anything the agent could not confirm is labeled 「未確認」 rather than
   asserted, per [answer-policy.md](../../rules/common/answer-policy.md).

## Notes

- This skill is **research only**. If a config change turns out to be needed, present the answer and
  wait for the user's instruction — never change files on your own.
- In offline environments the agent may fail to fetch the official docs. In that case answer from
  the agent's existing knowledge only and say so explicitly.
