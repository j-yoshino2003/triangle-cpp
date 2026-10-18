# Git Workflow

> Japanese reference translation: `docs/ja-JP/rules/common/git-workflow.md`.

## Commit Message Format
```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

## Branches

Standard Git flow: two long-lived branches and three kinds of short-lived branch.

| Branch | Cut from | Merges into | Purpose |
|--------|----------|-------------|---------|
| `main` | — | — | Released code only. Every merge here gets a version tag |
| `develop` | — | — | Integration branch. The next release accumulates here |
| `feature/<name>` | `develop` | `develop` | One change: a fix, a feature, a refactor |
| `release/<version>` | `develop` | `main` **and** `develop` | Release preparation: version bump, final fixes |
| `hotfix/<version>` | `main` | `main` **and** `develop` | An urgent fix against what is already released |

- A `feature/*` pull request targets `develop`. A `release/*` or `hotfix/*` pull request targets
  `main`, and the same change is merged back into `develop` — otherwise the next release loses it.
- Never commit directly to `main` or `develop`.
- `<name>` says what the change is, not just a ticket number (`feature/swapchain-resize`, not
  `feature/123`). `<version>` is the version being shipped (`release/1.4.0`, `hotfix/1.3.2`).
- The base defaults to `develop` everywhere (`git diff`, the review skill's `--base`, `gh pr create`).
  On a `release/*` or `hotfix/*` branch, say `--base main` explicitly — against `develop` the diff is
  the wrong one.

## Start and Finish of a Task

These apply to **every** piece of work — `team-change`, `/speckit.implement`, and a plain "fix
this" request alike.

- **Start**: before the first edit, make sure the checkout is on a short-lived branch. If it is on
  `develop` or `main`, create `feature/<name>` from `develop` first — or `hotfix/<version>` from
  `main` when the fix is against released code.
- **Finish**: the work is complete only when the edits build and the user has been handed
  `/review-pr working` to run in a new session on this checkout (the diff against `develop`,
  uncommitted changes included). Commit, push, and the pull request come after that review, each
  with the user's yes. Stopping before the review handoff is allowed only when the user asks
  for it.

## Pull Request Workflow

When creating PRs:
1. Analyze full commit history (not just latest commit)
2. Use `git diff develop...HEAD` to see all changes
3. Draft comprehensive PR summary
4. Include test plan with TODOs

## Review Handoff

The session that writes a change does not review it. Review runs in a **new session** with
`/review-pr` (the `git-pr-cross-review` skill): `/review-pr <PR number>` once the branch is
pushed, or `/review-pr working` on the same checkout before committing or pushing. Reports land in
`docs/reviews/`. Fixes go back onto the same branch and are re-reviewed the same way.

### This Project: Push Is Allowed, but Confirm First

`scm-guard` permits a plain `git push`, so Claude may push a branch and then open the PR with
`gh pr create`. **Always state which branch is about to be pushed and get a yes before running it** —
a push is outward-facing and the user wants to see the target every time.

What stays blocked is anything that rewrites or removes remote history:

| Blocked | Why |
|------|------|
| `git push --force` / `-f` / `--force-with-lease` | Overwrites commits already on the remote |
| `git push --delete` / `-d` / `origin :branch` | Removes a remote branch |
| `git push --mirror` | Can delete remote refs wholesale |
| `git send-email` | Sends patches outside the repository |
| `gh pr merge` / `close` / `edit` | Merging and PR state changes stay with the user |

When one of those is genuinely needed, hand the user the command instead of trying to work around
the guard.
