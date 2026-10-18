# 日本語リファレンス / Japanese Reference

このフォルダーは `.claude/` 配下の規約・スキル（英語・正本）の**日本語訳リファレンス**です。

- 正本は `.claude/rules/**` と `.claude/skills/**`（Claude Code が実際に読み込むのはそちら）
- 内容を変更する場合は、必ず英語の正本を先に更新し、この日本語訳を追随させる
- 階層は正本と対応させる
  - 規約: `rules/<カテゴリ>/<ファイル名>.md` ← `.claude/rules/<カテゴリ>/<ファイル名>.md`
  - スキル: `skills/<スキル名>.md` ← `.claude/skills/<スキル名>/SKILL.md`

## 収録内容

| 日本語訳 | 正本 |
|------|------|
| `rules/common/answer-policy.md` | `.claude/rules/common/answer-policy.md` |
| `rules/common/code-comments.md` | `.claude/rules/common/code-comments.md` |
| `rules/common/code-layout.md` | `.claude/rules/common/code-layout.md` |
| `rules/common/coding-style.md` | `.claude/rules/common/coding-style.md` |
| `rules/common/git-workflow.md` | `.claude/rules/common/git-workflow.md` |
| `rules/common/p4-workflow.md` | `.claude/rules/common/p4-workflow.md` |
| `rules/cpp/coding-style.md` | `.claude/rules/cpp/coding-style.md` |
| `rules/csharp/coding-style.md` | `.claude/rules/csharp/coding-style.md` |
| `rules/rust/coding-style.md` | `.claude/rules/rust/coding-style.md` |
| `rules/unity/coding-style.md` | `.claude/rules/unity/coding-style.md` |
| `rules/unreal/coding-style.md` | `.claude/rules/unreal/coding-style.md` |
| `skills/ask-claude-code.md` | `.claude/skills/ask-claude-code/SKILL.md` |
| `skills/git-pr-cross-review.md` | `.claude/skills/git-pr-cross-review/SKILL.md` |
| `skills/p4-cl-cross-review.md` | `.claude/skills/p4-cl-cross-review/SKILL.md` |
| `skills/team-change.md` | `.claude/skills/team-change/SKILL.md` |
| `skills/codex/ask-codex.md` | `.codex/skills/ask-codex/SKILL.md` |
| `skills/codex/git-pr-cross-review.md` | `.codex/skills/git-pr-cross-review/SKILL.md` |
| `skills/codex/p4-cl-cross-review.md` | `.codex/skills/p4-cl-cross-review/SKILL.md` |
| `skills/codex/team-change.md` | `.codex/skills/team-change/SKILL.md` |
| `skills/antigravity/ask-antigravity.md` | `.agent/skills/ask-antigravity/SKILL.md` |
| `skills/antigravity/git-pr-cross-review.md` | `.agent/skills/git-pr-cross-review/SKILL.md` |
| `skills/antigravity/p4-cl-cross-review.md` | `.agent/skills/p4-cl-cross-review/SKILL.md` |
| `skills/antigravity/team-change.md` | `.agent/skills/team-change/SKILL.md` |

`harness-guide.html` はハーネス全体の使い方ガイド、`speckit_guide.html` は spec-kit（`/speckit.*`）の
使い方ガイドです（どちらも日本語のみで、英語正本を持ちません）。

> NOTE: Codex 版（`.codex/rules/`）と Antigravity 版（`.agent/rules/`）の規約は `.claude/rules/` の **複製** で、
> どちらも `common-*.md`（answer-policy / code-comments / code-layout / coding-style / git-workflow / p4-workflow）と
> `<言語>-coding-style.md` を持ちます。
> `AGENTS.md` はどのファイルをいつ読むかを指示するだけです。規約の日本語訳は上の `rules/` をそのまま使います。
> 正本を変更したら両方の複製も更新してください（確認コマンドはリポジトリの `CLAUDE.md`）。
