---
name: ask-codex
description: Answers questions about Codex itself — config.toml, AGENTS.md, hooks, skills, subagents, MCP servers, sandbox and approval policy, slash commands — by researching the official documentation and reporting back in Japanese. Trigger it with questions like "Can Codex do X?" or "What does this setting mean?"
---

# ask-codex

> Japanese reference translation: `docs/ja-JP/skills/codex/ask-codex.md`.

## Purpose

Take a question about Codex's own behavior, configuration, or extension points, research it against
the **official documentation**, and return an evidence-backed answer in Japanese.

Questions in scope:

- Whether a feature exists and how to use it ("Can a hook block a specific command?", "How do I
  define a subagent?")
- What a setting means and how to write it (`config.toml` / `AGENTS.md` / approval policy /
  sandbox mode / environment variables)
- Slash commands and keyboard shortcuts
- Connecting and managing MCP servers
- Skills and plugins

> **Codex ships no built-in documentation-research agent**, so this skill researches the official
> docs directly instead of delegating.

## User Input

The question is passed as an argument.

### Argument check

If the question is empty, print the following and **stop**:

```
エラー: Codex について調べたい質問を記述してください。

使い方:
  /prompts:ask-codex <質問>

例:
  /prompts:ask-codex PreToolUse フックで特定のコマンドだけブロックできる?
  /prompts:ask-codex .codex/config.toml と ~/.codex/config.toml の優先順位は?
```

## Workflow

1. **Research the official documentation**. Start from these entry points and follow the links that
   match the question:
   - Config reference: `https://developers.openai.com/codex/config-file/config-reference`
   - Config basics: `https://developers.openai.com/codex/config-file/config-basic`
   - AGENTS.md: `https://developers.openai.com/codex/agent-configuration/agents-md`
   - Subagents: `https://developers.openai.com/codex/agent-configuration/subagents`
   - Hooks: `https://developers.openai.com/codex/hooks`
   - Skills and plugins: `https://developers.openai.com/codex/skills-and-plugins`
   - Slash commands: `https://developers.openai.com/codex/reference/slash-commands`
   - Sandboxing: `https://developers.openai.com/codex/sandboxing`
   - MCP: `https://developers.openai.com/codex/extend/mcp`

   Web access requires `web_search` to be enabled in `config.toml` (`cached` / `indexed` / `live`).
   When it is `disabled` or the environment is offline, say so explicitly and answer from existing
   knowledge only.

2. **Report back** in Japanese, organized for the user.
   - Show settings and command examples in code blocks.
   - Include the URLs of the documentation pages you actually read.

3. **Handling uncertainty**: anything you could not confirm in the documentation is labeled 「未確認」
   rather than asserted, per `.codex/rules/common-answer-policy.md`. Never present a plausible-looking
   config key as fact without having seen it in the docs.

## Notes

- This skill is **research only**. If a config change turns out to be needed, present the answer and
  wait for the user's instruction — never change files on your own.
- Codex's own documentation moves quickly. When a page 404s, search from
  `https://developers.openai.com/codex/` rather than guessing the new path.
