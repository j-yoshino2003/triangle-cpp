---
name: ask-antigravity
description: Answers questions about Antigravity itself — settings.json, permissions, hooks, skills, plugins, subagents, MCP servers, sandbox, slash commands — by researching the official documentation and reporting back in Japanese. Trigger it with questions like "Can Antigravity do X?" or "What does this setting mean?"
---

# ask-antigravity

> Japanese reference translation: `docs/ja-JP/skills/antigravity/ask-antigravity.md`.

## Purpose

Take a question about Antigravity's own behavior, configuration, or extension points, research it
against the **official documentation**, and return an evidence-backed answer in Japanese.

Questions in scope:

- Whether a feature exists and how to use it ("Can a hook block a specific command?", "How do I
  define a subagent?")
- What a setting means and how to write it (`settings.json` / permissions / sandbox / execution
  modes)
- Slash commands and keyboard shortcuts
- Connecting and managing MCP servers
- Skills, plugins, rules, and workflows

> **Antigravity ships no built-in documentation-research agent**, so this skill researches the
> official docs directly instead of delegating.

## User Input

The question is passed as an argument.

### Argument check

If the question is empty, print the following and **stop**:

```
エラー: Antigravity について調べたい質問を記述してください。

使い方:
  /ask-antigravity <質問>

例:
  /ask-antigravity PreToolUse フックで特定のコマンドだけブロックできる?
  /ask-antigravity permissions の allow / deny / ask の優先順位は?
```

## Workflow

1. **Research the official documentation**. Start from these entry points and follow the links that
   match the question:
   - CLI overview: `https://antigravity.google/docs/cli/overview`
   - CLI settings: `https://antigravity.google/docs/cli/settings`
   - CLI permissions: `https://antigravity.google/docs/cli/permissions`
   - CLI sandbox: `https://antigravity.google/docs/cli/sandbox`
   - CLI subagents: `https://antigravity.google/docs/cli/subagents`
   - CLI plugins and skills: `https://antigravity.google/docs/cli/plugins`
   - CLI reference (slash commands, shortcuts): `https://antigravity.google/docs/cli/reference`
   - Skills: `https://antigravity.google/docs/skills`
   - Rules and workflows: `https://antigravity.google/docs/rules-workflows`
   - Hooks: `https://antigravity.google/docs/hooks`
   - Plugins: `https://antigravity.google/docs/plugins`
   - MCP: `https://antigravity.google/docs/mcp`

   Note that the docs are split between **Antigravity CLI**, **Antigravity IDE**, and
   **Antigravity 2.0**. A feature documented for the IDE does not automatically exist in the CLI —
   say which surface the page you read describes.

   When the environment is offline, say so explicitly and answer from existing knowledge only.

2. **Report back** in Japanese, organized for the user.
   - Show settings and command examples in code blocks.
   - Include the URLs of the documentation pages you actually read.

3. **Handling uncertainty**: anything you could not confirm in the documentation is labeled 「未確認」
   rather than asserted, per `.agent/rules/common-answer-policy.md`. Never present a
   plausible-looking config key as fact without having seen it in the docs.

## Notes

- This skill is **research only**. If a config change turns out to be needed, present the answer and
  wait for the user's instruction — never change files on your own.
- Antigravity's own documentation moves quickly. When a page 404s, search from
  `https://antigravity.google/docs/getting-started` rather than guessing the new path.
