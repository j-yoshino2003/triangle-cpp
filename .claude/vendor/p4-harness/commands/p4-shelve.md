---
description: "Shelve opened files into a described changelist — describe what to shelve in plain language, confirm, then p4 shelve"
argument-hint: "[CL number | target description] (blank = everything opened)"
---

# Smart Shelve

> Perforce counterpart of `/prp-commit`. Follows `p4-workflow`.

**Input**: $ARGUMENTS

---

## Phase 1 — ASSESS

```bash
bash .claude/vendor/p4-harness/scripts/p4-connect.sh && p4 -p "$P4_PROXY" opened
```

If nothing is opened → stop: 「開いているファイルがありません。」

Show the user what is opened, grouped by changelist (`default` and each numbered CL), with the
action (edit / add / delete) per file.

---

## Phase 2 — INTERPRET & SELECT

Interpret `$ARGUMENTS` to decide what goes into the changelist:

| Input | Interpretation | Command |
|---|---|---|
| *(blank)* | Everything opened, in every CL | shelve each numbered CL; move `default` files into a new CL first |
| `12345` | That pending CL as it is | `p4 shelve -c 12345` |
| `default` | Files in the default changelist | create a CL, `p4 reopen -c N` them |
| `*.cpp` / `*.h` | Opened files matching the glob | `p4 reopen -c N <matches>` |
| `the lobby changes` | Interpret from the opened list and `p4 diff` | `p4 reopen -c N <matched files>` |
| Specific paths | Those files | `p4 reopen -c N <files>` |

For natural language, cross-reference `p4 opened` and `p4 -p "$P4_PROXY" diff -du <file>` to
find the relevant files. Show the user which files you selected and why.

If files are still in `default`, create a numbered changelist now (Phase 3) and move them with
`p4 -p "$P4_PROXY" reopen -c N <files>`.

If nothing matched, stop: 「指定に一致するファイルがありません。」

---

## Phase 3 — DESCRIBE

If the target CL has no description yet (new CL, or description is `<enter description here>`),
write one in the p4-workflow format:

```
<type>: <description>

<why, in Japanese>
```

Create or update it:

```bash
p4 -p "$P4_PROXY" change -i <<'EOF'
Change: new
Description:
	{type}: {description}
	
	{body}
EOF
```

(For an existing CL, use `Change: N` and keep its `Files:` block.)

---

## Phase 4 — CONFIRM & SHELVE

Present, then ask with `AskUserQuestion` whether to shelve now:

```
CL:      {N}
説明:    {type}: {description}
ファイル: {count} 件
  edit   //depot/...
  add    //depot/...
```

- **Yes** → `p4 -p "$P4_PROXY" shelve -c N` (use `shelve -r -c N` when the CL already has shelved
  files). The pre-shelve hook scans the files; if it blocks, fix the reported lines and re-run.
- **No** → stop and leave the CL as it is.

---

## Phase 5 — OUTPUT

```
シェルブ完了: CL {N}
説明:        {type}: {description}
ファイル:    {count} 件

次のステップ:
  /review-cl {N}      → 新しいセッションでクロスレビュー
  P4V で submit       → レビューが通ったらユーザーが実施
```

---

## Examples

| You say | What happens |
|---|---|
| `/p4-shelve` | Every opened file, one CL per existing CL, default files get a new CL |
| `/p4-shelve 12345` | Shelves CL 12345 after confirmation |
| `/p4-shelve default` | Moves default-CL files into a new described CL and shelves it |
| `/p4-shelve *.h` | Only opened headers |
| `/p4-shelve the private lobby dialog` | Finds the related opened files from the diff |
