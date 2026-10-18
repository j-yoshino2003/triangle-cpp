---
name: p4-workflow
description: Perforce workflow for this harness — how Claude opens files, builds a numbered pending changelist with a <type>: <description> description, shelves it for review after user confirmation, and what it must never do (submit, revert, delete shelves). Use when editing files under Perforce control, creating or shelving a changelist, or when a p4 command is about to be run.
---

# Perforce Workflow

The Perforce counterpart of `git-workflow`. Read this before any `p4` command.

## When to Activate

- Editing a file that lives in the Perforce workspace (`cpp/...`, `rust/...`)
- Creating a pending changelist or writing its description
- Shelving a changelist for review, or re-shelving after fixes
- Answering "what is open / what is pending" questions (`/p4-status`)
- Deciding whether a p4 command is allowed at all

## Connection

- Every p4 command goes through the proxy: `p4 -p "$P4_PROXY" <command>`. `P4_PROXY` holds
  `ssl:<host>:<port>`. If it is unset, ask the user for it and stop.
- Check the ticket first with `bash .claude/vendor/p4-harness/scripts/p4-connect.sh`. It logs in
  with `P4PASSWD` when possible and otherwise tells you to ask the user to log in.
- Read-only lookups that need no client: `describe`, `changes`, `files`, `filelog`, `print`.
  Anything about opened files (`opened`, `edit`, `shelve`, `where`) needs the user's workspace,
  which exists on the development machine only.

## What Claude May Do

| Operation | Allowed | Notes |
|-----------|---------|-------|
| `p4 edit` / `p4 add` / `p4 delete` | Yes | Always into a numbered changelist (`-c N`), never the default one once a CL exists |
| `p4 change -i` (create pending CL) | Yes | Description in the format below |
| `p4 reopen -c N` | Yes | Move files between pending CLs |
| `p4 shelve -c N` | **After user confirmation** | Show CL number, description, and file list first; the reminder hook repeats this |
| `p4 shelve -r -c N` / `-f` | After confirmation | Re-shelve after fixing review findings |
| `p4 unshelve` | Yes, own CL only | Never over someone else's opened files |
| `p4 submit` | **Never** | Blocked by scm-guard and p4-harness. The user submits from P4V after review |
| `p4 revert` | **Never** | Blocked. Throwing work away is the user's decision |
| `p4 shelve -d` / `p4 change -d` / `p4 obliterate` | **Never** | Blocked. Destructive |

When a blocked operation is genuinely needed, hand the user the exact command or the P4V steps
instead of working around the guard.

## Changelist Description Format

```
<type>: <description>

<optional body in Japanese: why the change is needed, what to verify>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci` — the same set as the
commit rule. First line under 72 characters, imperative, no trailing period. The shelve quality
hook warns when the first line does not match.

Creating a changelist with that description (heredoc keeps the tab-indented body intact):

```bash
p4 -p "$P4_PROXY" change -i <<'EOF'
Change: new
Description:
	fix: フレンド一覧の再表示で古いデータが残る不具合を修正
	
	2 回目以降にキャッシュを破棄していなかった。
EOF
```

`p4 change -i` prints `Change N created.`; use that `N` for every following `-c`.

## Standard Flow (implementation session)

1. **Open files into a CL**: create the CL first, then `p4 -p "$P4_PROXY" edit -c N <file>` for
   each file to be changed (`add` for new files, `delete` for removals).
2. **Edit** with the `Edit` tool as usual. Perforce files are CRLF + BOM — never rewrite them with
   a script (see `rules/common/answer-policy.md`).
3. **Build / test**, then run `/p4-status` to confirm exactly the intended files are in the CL and
   nothing is left in `default`.
4. **Shelve**: present CL number, description, and file list, get a yes, then
   `p4 -p "$P4_PROXY" shelve -c N`. The quality hook scans the files (secrets block; debug
   leftovers warn) and the post hook prints the review handoff.
5. **Hand off**: review happens in a **separate session** — `/review-cl N`. Do not review here.
6. **After review**: fix findings in the same CL, rebuild, `p4 shelve -r -c N`, and ask for a
   re-review with the same command.
7. **Submit**: the user's step in P4V, after the review is clean.

## Read-Only Commands (safe anywhere)

| Purpose | Command |
|---------|---------|
| Files opened, grouped by CL | `p4 -p "$P4_PROXY" opened` / `opened -c N` |
| My pending CLs | `p4 -p "$P4_PROXY" changes -s pending -u "$P4USER"` |
| CL metadata | `p4 -p "$P4_PROXY" describe -s N` |
| Shelved diff | `p4 -p "$P4_PROXY" describe -S -du5 N` |
| Local path of a depot file | `p4 -p "$P4_PROXY" where //depot/path` |
| File history | `p4 -p "$P4_PROXY" filelog //depot/path` |
| Depot file content without syncing | `p4 -p "$P4_PROXY" print -q //depot/path` |

## Anti-Patterns

```
# BAD: editing a file that was never opened (Perforce marks it read-only; the edit fails or is lost)
# GOOD: p4 edit -c N first

# BAD: leaving files in the default changelist and shelving "whatever is there"
# GOOD: one numbered CL per change, with a description, verified by /p4-status

# BAD: shelving without telling the user which CL and which files
# GOOD: show CL / description / files, get a yes, then shelve

# BAD: reviewing the CL in the same session that wrote it
# GOOD: /review-cl N in a new session

# BAD: p4 revert to "clean up"
# GOOD: tell the user what is open and let them decide in P4V
```

## Quick Reference

| Task | Command |
|------|---------|
| Check connection | `bash .claude/vendor/p4-harness/scripts/p4-connect.sh` |
| Create CL | `p4 -p "$P4_PROXY" change -i <<'EOF' ... EOF` |
| Open for edit | `p4 -p "$P4_PROXY" edit -c N <file>` |
| Add new file | `p4 -p "$P4_PROXY" add -c N <file>` |
| Move file to CL | `p4 -p "$P4_PROXY" reopen -c N <file>` |
| Shelve | `p4 -p "$P4_PROXY" shelve -c N` |
| Re-shelve | `p4 -p "$P4_PROXY" shelve -r -c N` |
| Fetch shelved diff (review machine) | `bash .claude/vendor/p4-harness/scripts/p4-describe.sh N --diff` |
| Review | `/review-cl N` (new session) |
