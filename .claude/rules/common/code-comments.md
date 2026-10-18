---
paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.hh"
  - "**/*.cxx"
  - "**/*.h"
  - "**/*.cs"
  - "**/*.csx"
  - "**/*.rs"
  - "**/CMakeLists.txt"
---
# Comment Rules

> Loaded only when a source file is read or edited (see `paths:` above). The design rules that
> always apply live in `coding-style.md` (`common-coding-style.md` in the Codex and Antigravity
> copies).
> Japanese reference translation: `docs/ja-JP/rules/common/code-comments.md`.

## Comments

Write plainly enough for a beginner; explain *why*, not just *what*.

Rules for Japanese comments in code:

| Rule | Example |
|------|----|
| End each comment line with a period | `// プレイヤー数.` |
| Space between full-width and half-width characters | `プレイヤー ID` |
| Add a long-vowel mark to `-er` / `-or` / `-ar` katakana endings | Player → プレイヤー |

- Declarations get a one-line comment directly above them
- Function definitions, classes, structs, and enums use XML-style (`/// <summary>`) comments
- `// TODO:` marks remaining work; `// NOTE:` marks reminders and cautions
- A `TODO` / `NOTE` that spans 2 or more lines breaks right after the label, with the body starting on the next line
- A `bool` **parameter or return value** spells out **both** cases as `true = ... , false = ...` —
  the name alone rarely says what the false branch means. This covers language-specific boolean
  types too (`VkBool32`, `BOOL`, …), written with that type's own literals

```cpp
// ❌ false のときに何が起きるのか読み取れない.
/// <param name="isVisible">表示するかどうか.</param>
/// <returns>有効なら true.</returns>

// ✅ 両方の意味を書く.
/// <param name="isVisible">true = 表示する、false = 隠す.</param>
/// <returns>true = 有効、false = 無効.</returns>
```

```cpp
// ✅ One line: keep the body on the label line.
// TODO: リトライ回数を設定ファイルへ移す.

// ✅ Two lines or more: break right after TODO: / NOTE:.
// TODO:
// リトライ回数を設定ファイルへ移す.
// サーバー側の設定 API が入ってから対応する.
```

### Never Record Change History

A comment explains **why the current code needs to be this way**. It never records what changed,
what the code used to be, or which alternative was rejected. Version control already holds that,
and a note about a past edit goes stale the moment the next edit lands.

| ❌ | ✅ |
|----|----|
| `// NOTE: 一時的に無効化していたが元に戻した.` | Delete it |
| `// 以前は List を使っていたが遅いので変更.` | `// 要素数が固定なので配列を使う.` |
| `// TODO: 2026/08/16 追加.` | Delete it — the date is in the log |
| `// 修正: #1234 対応.` | `// 負の残量を 0 に丸める. UI が負値を表示できないため.` |

Also delete, rather than keep:

- commented-out code — version control remembers it
- `// 変更履歴` blocks and per-edit changelogs at the top of a file
- a ticket number on its own, with no explanation of the reason

The test: **would this comment still make sense to someone reading the file for the first time,
with no knowledge of its past?** If it only makes sense as a record of an edit, it does not belong
in the code. When a decision genuinely needs to be written down and it is not evident from the code,
put it in `.claude/rules/` or the relevant `README.md`.
