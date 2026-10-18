---
name: team-change
description: Give it a bug report or a change request and it orchestrates the investigator and implementer subagents through investigation/design -> spec update (specs/<feature>/spec.md, before any code) -> implementation -> lead check -> handoff for review in a separate session via /git-pr-cross-review working. Review is deliberately NOT part of this skill, and the commit, the push and the pull request come after that review. Trigger it with the symptoms of the bug or the change you want made.
---

# team-change (Antigravity)

> Japanese reference translation: `docs/ja-JP/skills/antigravity/team-change.md`.
> Claude Code counterpart: `.claude/skills/team-change/SKILL.md` (Agent Teams). Same phases, same
> deliverables; here the lead orchestrates subagents instead of a team.

## Purpose

Take a **bug report or a change request** and drive it to a reviewable state on a work branch:
investigation / design, spec update, implementation, and a lead check. **You (the main session) are
the lead and the orchestrator**: you call `invoke_subagent` for the subagents defined in
`.agent/agents/`, pass each one everything it needs, and aggregate the results.

Two things distinguish this skill from a plain "fix it" request:

- **Spec first.** The behavior after the change is written into `specs/<feature>/spec.md` **before**
  any source file is touched, and the code is then implemented against that spec.
- **No review inside the skill.** Review happens in a **separate session** with
  `/git-pr-cross-review working` on this checkout — the diff against `develop`, uncommitted
  changes included. This skill ends by handing the user that exact command. The commit, the push,
  and the pull request come **after** that review, each with the user's yes (per
  `.agent/rules/common-git-workflow.md`).

Target: **bug fixes and small-to-medium feature changes whose intent is clear.** It is NOT for
open-ended requirements or large work spanning multiple components.

> **Antigravity has no shared task list.** Subagents cannot see each other's state. You are the
> only place where results come together, so you must pass every piece of context a subagent needs
> directly in its prompt (the request, the investigation result, the spec summary, the constraints).

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

**Never invoke a subagent when no request was given.**

### When the request is ambiguous

If the request does not determine one behavior (an important branch is undefined, or the bug's
expected behavior is unclear), **do not guess**: organize the open points and confirm them with
the user, per `.agent/rules/common-answer-policy.md`. Do this before the spec is written, because
the spec must not contain guesses.

## Constraints (MUST be enforced)

Subagents read `AGENTS.md`, but to make them binding you **must restate every constraint below in
each subagent prompt**.

- **Editable scope**: file creation and editing are limited to the paths allowed by the work-scope
  rule in `AGENTS.md`. The `PreToolUse` hook in the `coding-harness` plugin denies anything else.
  `specs/` is inside that scope. If a change outside the scope turns out to be needed, do not make
  it — confirm with the user.
- **Spec before code**: no source file is edited until the spec update in phase 2 is done and
  reported. Code that contradicts the spec is a defect, not a shortcut.
- **Coding standards**: all implementation follows the rules under `.agent/rules/`
  (`common-coding-style.md` / `cpp-coding-style.md` / `rust-coding-style.md`, and so on).
- **Simplicity first**: KISS / YAGNI from the common rules. The minimum change that satisfies the
  spec.
- **Language**: all documentation, comments, spec text, and user-facing reports are written in
  Japanese.
- **Exactly one editor**: to avoid file conflicts, **only the `implementer` subagent edits files**
  (the spec included). The `investigator` is instructed to be read-only in its prompt and returns
  findings.
- **Git rules**: work on a work branch, never on `develop` or `main`. Follow
  `.agent/rules/common-git-workflow.md`: a push happens only after the branch name has been shown
  to the user and they said yes. Never force-push, never delete remote branches, never merge —
  `scm-guard` blocks those anyway.

> **Antigravity subagents have no documented "read-only" execution mode.** Read-only status is
> enforced by stating "never edit files" in the agent instructions plus the edit-scope hook, so
> **always restate "never edit files" in the prompt of the `investigator`**.

---

## Subagents

| Subagent | Role | Edits |
|----------|------|-------|
| `investigator` | Bug: identifies the root cause and blast radius. Change: identifies the affected code, the approach, and the target files. Also locates the spec to update | Read-only |
| `implementer` | Updates the spec, then applies the change per the investigation and runs build/tests (**the only editor**) | Edit allowed (scope-limited) |

The **lead** (you) performs the final check in phase 4 and the manual / handoff in phase 5
yourself; no reviewer subagents are invoked.

**Order**: `investigation` -> `spec update` -> `implementation` -> `lead check` -> `manual & handoff`

---

## Workflow

At the start of each phase, print the current phase name to the user in one line.

### Phase 0: Preparation

As the lead, make sure the checkout is on a short-lived branch (create `feature/<name>` from the
current `develop` if it is not; `<name>` is 2-4 lowercase words joined by `-`), per
`.agent/rules/common-git-workflow.md`, "Start and Finish of a Task".

### Phase 1: Investigate / Design

Invoke the **`investigator`** subagent with `invoke_subagent`. Its prompt must contain the request
verbatim, the constraints above, and the following instructions (no editing):

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
- Return, structured: `根本原因 / 実装方針` (file path:line number + explanation) / `関連箇所` /
  `対象ファイル` / `仕様書の対象` (path, existing or new, sections to change).

> If the root cause cannot be identified (bug) or the approach depends on an undecided point
> (change), do not guess: report the established facts and the open questions to the user and stop.

### Phase 2: Spec update

Invoke the **`implementer`** subagent with `invoke_subagent` for the spec only (no source files
yet). Its prompt must contain the request, the investigator's result, the constraints, and:

- **Existing spec**: edit `specs/<feature>/spec.md` so it describes the behavior **after** the
  change. Update the affected user stories, acceptance scenarios (`Given / When / Then`), and
  functional requirements. For a bug, add or correct the acceptance scenario that the bug violated
  (the scenario that would have caught it).
- **New spec**: create `specs/<NNN>-<short-name>/spec.md` from
  `.specify/templates/spec-template.md`. Fill in only what the request determines; mark anything
  still unknown as `[NEEDS CLARIFICATION: ...]` and report it instead of inventing it.
- Keep the spec about **what** the behavior is, not how it is implemented (no file names, no type
  names).
- Return a "spec summary": the spec path, whether it is new or existing, and the sections that
  changed (before -> after in one line each).

> If writing the spec exposes an ambiguity that phase 1 missed, stop here and confirm with the
> user. Do not proceed to code with an ambiguous spec.

### Phase 3: Implement

Invoke the **`implementer`** subagent again with `invoke_subagent`. Its prompt must contain the
request, the investigator's result, the spec summary, the constraints, and:

- Follow the investigation's approach and make the minimum change within the editable scope that
  satisfies the updated spec (simplicity first, standards strictly followed).
- Build/test verification:
  - Run the project's build (`cargo build` / `cargo test` for `rust/`, the CMake or compiler
    invocation the project documents for `cpp/`) and fix any errors.
  - When logic changes, write and run the corresponding unit tests.
  - Where no automated build is available, say so explicitly and substitute a static check for
    standards compliance and consistency.
- Return the changed files, the changes, and the expected effect as a "change summary".

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

- State the reason and invoke `implementer` again with `invoke_subagent`, passing the fix
  instructions (spec, code, or both).
- After the fix, re-run this phase, max 2 rounds.
- If it has not converged after 2 rounds, report the remaining issues to the user and stop.

### Phase 5: Manual generation and review handoff

After the lead check passes:

1. **Generate the change manual** (spec below) and save it.
2. **Hand off**: present the saved path, the key points, and the review command
   `/git-pr-cross-review working` to run in a **new session on this checkout**. The work is
   complete at that handoff. Leave the changes uncommitted: per
   `.agent/rules/common-git-workflow.md` the commit, the push, and the pull request come after the
   review, each with the user's yes. Do not commit or push here — if the user asks for it
   mid-skill, point them at the review first.

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
  (1) the work branch and the changed files, still uncommitted, (2) in a new Antigravity session on
  this checkout run `/git-pr-cross-review working`, (3) after the review passes, commit, push, and
  open the pull request against `develop`, each with the user's yes.
- 注意事項・リスク: blast radius and potential risks, if any.
- 残課題: anything left undone or marked `[NEEDS CLARIFICATION]`, if any.

**HTML template**: use the same skeleton as the Claude Code version
(`.claude/skills/team-change/SKILL.md`, "HTML template"), with the review command replaced by
`/git-pr-cross-review working` and "この checkout の新しい Antigravity セッションで次を実行する".

---

## Final Report

Present, in this order:

1. The saved path of the HTML manual.
2. The spec path and a one-line summary of what changed in it.
3. The work branch and the changed source files, still uncommitted.
4. The review handoff, verbatim: run `/git-pr-cross-review working` in a new session on this
   checkout, and state that the commit, the push, and the pull request follow that review.

Add remaining issues and any further notes at the end.

## Notes

- **This skill does not review.** Do not invoke reviewer subagents and do not run
  `/git-pr-cross-review` here; the separate session is the review. Keeping the two apart is what
  makes the review independent.
- **The `implementer` subagent is the only editor**, for source files and for the spec alike. Never
  let the `investigator` edit (this prevents file conflicts).
- **Spec before code.** If the implementer starts on source files before the spec summary is
  reported, stop it and return to phase 2.
- Every subagent prompt must be self-contained: Antigravity has no shared task list, so anything
  you do not write into the prompt does not exist for that subagent.
- The moment a change outside the editable scope is required, stop and confirm with the user.
- **Do not commit or push in this skill.** Both come after the review, each with the user's yes,
  and a push happens only once the user has seen the branch name. Never force-push, never delete a
  remote branch, never merge the PR.
- Never assert uncertain points: separate established facts from open questions when reporting
  (per `.agent/rules/common-answer-policy.md`).
