# Perforce Workflow

> Japanese reference translation: `docs/ja-JP/rules/common/p4-workflow.md`.
> Full procedure: skill `p4-workflow` in `.claude/vendor/p4-harness/`.

## Changelist Description Format

```
<type>: <description>

<optional body in Japanese>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci — the same set as commit messages.

## Start and Finish of a Task

These apply to **every** piece of work that touches a Perforce-controlled file — `team-change`,
`/speckit.implement`, and a plain "fix this" request alike.

- **Start**: before the first edit, create a new pending changelist with `p4 change -i` and a
  `<type>: <description>` description, and open every file into it (`p4 edit -c N` / `add -c N`
  / `delete -c N`). Never leave files in the `default` changelist, and never reuse a changelist
  that belongs to other work.
- **Finish**: the work is complete only when the edits build, the changelist holds exactly the
  intended files (`/p4-status`), the user has approved the shelve, the changelist is shelved, and
  the user has been handed `/review-cl <CL>` to run in a new session. Stopping before the shelve
  is allowed only when the user asks for it.

## What Claude May Do

| Operation | Rule |
|-----------|------|
| `p4 edit` / `add` / `delete` / `reopen` / `change -i` | Allowed. Always into a numbered changelist with a description |
| `p4 shelve` | Allowed **after** showing the user the CL number, description, and file list and getting a yes |
| `p4 submit` / `revert` / `shelve -d` / `change -d` / `obliterate` | Blocked by `scm-guard` and `p4-harness`. The user does these in P4V |

Every p4 command goes through `p4 -p "$P4_PROXY"`; `P4_PROXY` is the reachable server address
and is never written into a file.

## Review Handoff

The session that writes a change does not review it. After shelving, review runs in a **new
session** with `/review-cl <CL>` (the `p4-cl-cross-review` skill). Fixes go back into the same
changelist, re-shelved with `p4 shelve -r -c <CL>`, then re-reviewed.

When a blocked operation is genuinely needed, hand the user the command or the P4V steps instead
of trying to work around the guard.
