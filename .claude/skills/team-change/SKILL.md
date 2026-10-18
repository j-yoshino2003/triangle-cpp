---
name: team-change
description: Give it a bug report or a change request and it forms an Agent Team that runs investigation/design -> spec update (specs/<feature>/spec.md, before any code) -> implementation -> lead check -> handoff for review in a separate session via /review-pr working. Review is deliberately NOT part of this skill, and the commit, the push and the pull request come after that review. Trigger it with the symptoms of the bug or the change you want made.
---

# team-change

> Japanese reference translation: `docs/ja-JP/skills/team-change.md`.

## Purpose

Take a **bug report or a change request**, form an **Agent Team (a team of teammates)**, and drive
it to a reviewable state on a work branch: investigation / design, spec update, implementation, and
a lead check. The main session (you) acts as the **team lead**: spawn teammates, assign tasks, and
aggregate results.

Two things distinguish this skill from a plain "fix it" request:

- **Spec first.** The behavior after the change is written into `specs/<feature>/spec.md` **before**
  any source file is touched, and the code is then implemented against that spec.
- **No review inside the skill.** Review happens in a **separate session** with
  `/review-pr working` on this checkout — the diff against `develop`, uncommitted changes
  included. This skill ends by handing the user that exact command. The commit, the push, and the
  pull request come **after** that review, each with the user's yes (per
  [git-workflow.md](../../rules/common/git-workflow.md)).

Target: **bug fixes and small-to-medium feature changes whose intent is clear.** It is NOT for
open-ended requirements or large work spanning multiple components.

> Precondition: Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). If it is
> disabled no team can be formed — tell the user and stop.

## User Input

The request is passed as an argument, in either form:

- **A bug report** (symptoms, repro steps, expected behavior — whatever the user knows)
- **A change request** (what to change, expected behavior, target module, in prose)
- **A path to an existing spec** (`specs/<feature>/spec.md`) plus what to change in it

### Argument check

If the argument is empty, print the following and **stop**:

```
エラー: 修正したい不具合、または変更したい内容を記述してください。

使い方:
  /team-change <不具合の内容 または 変更内容>

例:
  /team-change 三角形の頂点色が Rust 版だけ反転して表示される
  /team-change ウィンドウのリサイズに追従してスワップチェーンを再生成する
  /team-change specs/003-swapchain-resize/spec.md に最小化時の挙動を追加する
```

**Never form a team when no request was given.**

### When the request is ambiguous

If the request does not determine one behavior (an important branch is undefined, or the bug's
expected behavior is unclear), **do not guess**: organize the open points and confirm them with
`AskUserQuestion`, per [answer-policy.md](../../rules/common/answer-policy.md). Do this before the
spec is written, because the spec must not contain guesses.

## Constraints (MUST be enforced)

Teammates inherit the lead's permissions and read `CLAUDE.md` plus project settings, but to make
them binding you **must state every constraint below in the team-formation prompt**.

- **Editable scope**: Edit / Write are limited to the directories allowed by the work-scope rule in
  [AGENTS.md](../../../AGENTS.md). `specs/` is inside that scope. If a change outside the scope
  turns out to be needed, do not make it — confirm with the user.
- **Spec before code**: no source file is edited until the spec update in phase 2 is done and
  reported. Code that contradicts the spec is a defect, not a shortcut.
- **Coding standards**: all implementation follows the rules under `.claude/rules/`
  (`common/coding-style.md` / `cpp/coding-style.md` / `rust/coding-style.md`, and so on).
- **Simplicity first**: follow KISS / YAGNI from `.claude/rules/`. The minimum change that satisfies
  the spec.
- **Immutability**: create new objects, do not mutate existing ones, except on engine-managed hot
  paths where the engine rules say otherwise.
- **Edit with the `Edit` tool**: never rewrite an existing file with `Write`, `sed -i`, or a
  throwaway script (see [answer-policy.md](../../rules/common/answer-policy.md)).
- **Language**: all documentation, comments, spec text, and user-facing reports are written in
  Japanese.
- **Exactly one editor**: to avoid file conflicts, **only the Implementer teammate edits files**
  (the spec included). The Investigator is read-only and returns findings.
- **Git rules**: work on a work branch, never on `develop` or `main`. Follow
  [git-workflow.md](../../rules/common/git-workflow.md). No teammate commits, pushes, or opens a
  pull request: those come after the review in a separate session, each with the user's yes. Never
  force-push, never delete remote branches, never merge — `scm-guard` blocks those anyway.

---

## Team Composition

Form the team from the roles below. The lead spawns them as teammates and coordinates through the
shared task list.

| Teammate | Role | Edits |
|----------|------|-------|
| **Investigator** | Bug: identifies the root cause and blast radius. Change: identifies the affected code, the approach, and the target files. Also locates the spec to update | Read-only |
| **Implementer** | Updates the spec, then applies the change per the investigation and runs build/tests (**the only editor**) | Edit allowed (scope-limited) |

The **lead** (you) performs the final check in phase 4 and the manual / handoff in phase 5
yourself; no reviewer teammates are spawned.

**Task dependencies** (the lead manages these in the task list):
`investigation` -> `spec update` -> `implementation` -> `lead check` -> `manual & handoff`

---

## Workflow

At the start of each phase, print the current phase name to the user in one line.

### Phase 0: Team startup

As the lead, make sure the checkout is on a short-lived branch (create `feature/<name>` from the
current `develop` if it is not; `<name>` is 2-4 lowercase words joined by `-`). Then form the
teammates for the roles above and instruct them to coordinate through the shared task list. The
formation prompt must include the request and every item under "Constraints (MUST be enforced)".

### Phase 1: Investigate / Design

Instruct the **Investigator** (no editing):

- **Bug**: locate the code related to the reported symptoms and pin down the root cause (which
  file, which logic, and why it is wrong). Map the blast radius.
- **Change**: locate the code that implements the current behavior, decide the approach, and list
  the target files. Map the blast radius (callers, related modules, the other language port if the
  same feature exists in both `cpp/` and `rust/`).
- **Spec target**: find the spec that covers this feature.
  - Search `specs/*/spec.md` for the feature (module name, keywords from the request).
  - If one exists, report its path and the sections that must change.
  - If none exists, propose a new spec directory `specs/<NNN>-<short-name>/` where `NNN` is the
    highest existing number under `specs/` plus one (`001` when `specs/` is empty or missing) and
    `<short-name>` is 2-4 lowercase words joined by `-` (e.g. `003-swapchain-resize`). Do **not**
    run `.specify/scripts/bash/create-new-feature.sh` — the branch is already created in phase 0,
    and the script would create another one.
- Share the following, structured: `root cause / approach` (file path:line number + explanation) /
  `related areas` / `target files` / `spec target` (path, existing or new, sections to change).

> If the root cause cannot be identified (bug) or the approach depends on an undecided point
> (change), do not guess: report the established facts and the open questions to the user and stop
> (per [answer-policy.md](../../rules/common/answer-policy.md)).

### Phase 2: Spec update

Instruct the **Implementer** (spec only — no source files yet):

- **Existing spec**: edit `specs/<feature>/spec.md` so it describes the behavior **after** the
  change. Update the affected user stories, acceptance scenarios (`Given / When / Then`), and
  functional requirements. For a bug, add or correct the acceptance scenario that the bug violated
  (the scenario that would have caught it).
- **New spec**: create `specs/<NNN>-<short-name>/spec.md` from
  `.specify/templates/spec-template.md`. Fill in only what the request determines; mark anything
  still unknown as `[NEEDS CLARIFICATION: ...]` and report it instead of inventing it.
- Keep the spec about **what** the behavior is, not how it is implemented (no file names, no type
  names).
- Share a "spec summary": the spec path, whether it is new or existing, and the sections that
  changed (before -> after in one line each).

> If writing the spec exposes an ambiguity that phase 1 missed, stop here and confirm with the user
> through `AskUserQuestion`. Do not proceed to code with an ambiguous spec.

### Phase 3: Implement

Instruct the **Implementer**:

- Follow the investigation's approach and make the minimum change within the editable scope that
  satisfies the updated spec (simplicity first, standards strictly followed).
- Build/test verification:
  - Run the project's build (`cargo build` / `cargo test` for `rust/`, the CMake or compiler
    invocation the project documents for `cpp/`) and fix any errors.
  - When logic changes, write and run the corresponding unit tests.
  - Where no automated build is available, say so explicitly and substitute a static check for
    standards compliance and consistency.
- Share the changed files, the changes, and the expected effect as a "change summary".

### Phase 4: Lead check

The lead (you) performs this check yourself, read-only.

**(1) Request -> spec -> code adherence**

- Re-read the original request, the spec summary, and the change summary.
- Verify item by item:
  - Does the spec describe exactly what was requested, no more and no less?
  - Does the code implement the spec (every changed acceptance scenario has a matching code
    change)?
  - Did any extra, uninstructed change slip in (code or spec)?
- Any mismatch is a **hard block (send back)**.

**(2) Blast-radius check**

- Check the callers of and dependencies on the changed files.
- Verify the change introduced no unintended behavior change elsewhere.
- Any problem is a **hard block (send back)**.

**On a hard block**:

- State the reason and ask the Implementer to fix it (spec, code, or both).
- After the fix, re-run this phase, max 2 rounds.
- If it has not converged after 2 rounds, report the remaining issues to the user and stop.

### Phase 5: Manual generation and review handoff

After the lead check passes:

1. **Generate the change manual** (spec below) and save it.
2. **Hand off**: present the saved path, the key points, and the review command
   `/review-pr working` to run in a **new session on this checkout**. The work is complete at that
   handoff. Leave the changes uncommitted: per
   [git-workflow.md](../../rules/common/git-workflow.md) the commit, the push, and the pull request
   come after the review, each with the user's yes. Do not commit or push here — if the user asks
   for it mid-skill, point them at the review first.
3. Shut down all teammates.

**Manual output spec**:

- Destination: `docs/manuals/` (create the folder if missing).
- Filename: `<変更した概要>_<YYYYMMDD-HHMMSS>.html` (use the real timestamp, e.g. from the `date`
  command).
  - `<変更した概要>` is a short Japanese phrase summarizing the change (aim for 20 characters or
    fewer).
  - Do not use characters invalid in filenames (`\ / : * ? " < > |`) or spaces. Use a hyphen `-` as
    a separator when needed.
  - Example: `Rust版の頂点色反転を修正_20260918-153000.html`
- Format: a single HTML file with CSS embedded in `<style>` (no external references), openable
  directly in a browser.
- Encoding: UTF-8 (always include `<meta charset="UTF-8">`). Language attribute: `<html lang="ja">`.
- Save only to this path, which stays inside the editable scope (under `docs`). The manual is
  **not** committed — it is a local deliverable.

**Manual contents** (express this heading structure as HTML):

- 変更内容: the request / root cause or approach / list of changed files with a per-file change
  summary (the spec file included).
- 仕様書の更新: the spec path (new or existing) and each section that changed, before -> after.
- 責任者チェックの結果: adherence (request -> spec -> code) and blast radius.
- 動作確認手順: the steps and points the user should actually verify (for a bug, including how to
  confirm it no longer reproduces). Derive them from the spec's acceptance scenarios.
- レビュー依頼: the handoff. State that review is done in a separate session, and give the steps:
  (1) the work branch and the changed files, still uncommitted, (2) in a new Claude Code session on
  this checkout run `/review-pr working`, (3) after the review passes, commit, push, and open the
  pull request against `develop`, each with the user's yes.
- 注意事項・リスク: blast radius and potential risks, if any.
- 残課題: anything left undone or marked `[NEEDS CLARIFICATION]`, if any.

**HTML template** (generate along this skeleton; replace `{{ }}` with real content, and repeat rows
or elements when there are multiple items):

```html
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>変更マニュアル - {{ 変更の概要 }}</title>
<style>
  body { font-family: "Segoe UI", "Hiragino Kaku Gothic ProN", "Meiryo", sans-serif; line-height: 1.8; color: #1f2328; max-width: 960px; margin: 0 auto; padding: 2rem; background: #ffffff; }
  h1 { font-size: 1.8rem; border-bottom: 3px solid #2563eb; padding-bottom: 0.5rem; }
  h2 { font-size: 1.35rem; margin-top: 2rem; border-left: 5px solid #2563eb; padding-left: 0.6rem; }
  h3 { font-size: 1.1rem; margin-top: 1.5rem; color: #374151; }
  table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
  th, td { border: 1px solid #d0d7de; padding: 0.5rem 0.75rem; text-align: left; vertical-align: top; }
  th { background: #f0f4ff; }
  code { background: #f6f8fa; padding: 0.1rem 0.35rem; border-radius: 4px; font-family: "Consolas", "Courier New", monospace; font-size: 0.92em; }
  pre { background: #f6f8fa; padding: 1rem; border-radius: 6px; overflow-x: auto; font-family: "Consolas", "Courier New", monospace; font-size: 0.9em; }
  .meta { color: #6b7280; font-size: 0.9rem; }
  ul, ol { padding-left: 1.4rem; }
  .note { background: #fff7ed; border: 1px solid #fed7aa; border-radius: 6px; padding: 0.75rem 1rem; }
  .handoff { background: #eff6ff; border: 1px solid #93c5fd; border-radius: 6px; padding: 0.75rem 1rem; }
</style>
</head>
<body>
  <h1>変更マニュアル</h1>
  <p class="meta">生成日時: {{ YYYY-MM-DD HH:MM:SS }} ／ 対象: {{ 変更の概要 }} ／ ブランチ: <code>{{ feature/xxx }}</code></p>

  <h2>変更内容</h2>
  <h3>依頼内容</h3>
  <p>{{ 依頼内容の要約 }}</p>
  <h3>根本原因 ／ 実装方針</h3>
  <p>{{ 不具合なら根本原因、機能変更なら実装方針 }}</p>
  <h3>変更ファイル一覧</h3>
  <table>
    <thead><tr><th>ファイル</th><th>変更概要</th></tr></thead>
    <tbody>
      <tr><td><code>{{ specs/xxx/spec.md }}</code></td><td>{{ 仕様書の変更概要 }}</td></tr>
      <tr><td><code>{{ ファイルパス }}</code></td><td>{{ 変更概要 }}</td></tr>
    </tbody>
  </table>

  <h2>仕様書の更新</h2>
  <p>対象: <code>{{ specs/xxx/spec.md }}</code>（{{ 新規 / 既存 }}）</p>
  <table>
    <thead><tr><th>セクション</th><th>変更前</th><th>変更後</th></tr></thead>
    <tbody>
      <tr><td>{{ セクション名 }}</td><td>{{ 変更前 }}</td><td>{{ 変更後 }}</td></tr>
    </tbody>
  </table>

  <h2>責任者チェックの結果</h2>
  <ul><li>依頼 → 仕様 → コードの整合: {{ 結果 }}</li><li>影響範囲: {{ 結果 }}</li></ul>

  <h2>動作確認手順</h2>
  <ol><li>{{ 確認手順（仕様書の受け入れシナリオに対応させる） }}</li></ol>

  <h2>レビュー依頼</h2>
  <div class="handoff">
    <p>レビューは別セッションで行います。</p>
    <ol>
      <li>作業ブランチ <code>{{ feature/xxx }}</code>（未コミット。変更ファイル: {{ 変更ファイルの一覧 }}）</li>
      <li>この checkout の新しい Claude Code セッションで次を実行する</li>
    </ol>
    <pre>/review-pr working</pre>
    <p>レビューが通ったら、了承のうえで commit → push → PR（ベース <code>develop</code>）の順に進めます。</p>
  </div>

  <h2>注意事項・リスク</h2>
  <div class="note">{{ 影響範囲・潜在的リスク（無ければ「特になし」） }}</div>

  <h2>残課題</h2>
  <ul><li>{{ 未対応の事項・NEEDS CLARIFICATION（無ければ「なし」） }}</li></ul>
</body>
</html>
```

---

## Final Report

Present, in this order:

1. The saved path of the HTML manual.
2. The spec path and a one-line summary of what changed in it.
3. The work branch and the changed source files, still uncommitted.
4. The review handoff, verbatim: run `/review-pr working` in a new session on this checkout, and
   state that the commit, the push, and the pull request follow that review.

Add remaining issues and any further notes at the end.

## Notes

- If Agent Teams is disabled, do not form a team — say so and stop.
- **This skill does not review.** Do not spawn reviewer teammates and do not run `/review-pr`
  here; the separate session is the review. Keeping the two apart is what makes the review
  independent.
- **The Implementer teammate is the only editor**, for source files and for the spec alike. Never
  let the Investigator edit (this prevents file conflicts).
- **Spec before code.** If the Implementer starts on source files before the spec summary is
  reported, stop it and return to phase 2.
- The moment a change outside the editable scope is required, stop and confirm with the user.
- **Do not commit or push in this skill.** Both come after the review, each with the user's yes,
  and a push happens only once the user has seen the branch name. Never force-push, never delete a
  remote branch, never merge the PR.
- Note that teammates inherit the lead's permission mode (the lead's permission settings apply to
  the whole team).
- Never assert uncertain points: separate established facts from open questions when reporting
  (per [answer-policy.md](../../rules/common/answer-policy.md)).
