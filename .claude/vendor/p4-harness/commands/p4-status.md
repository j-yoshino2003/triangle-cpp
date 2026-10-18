---
description: Show opened files grouped by changelist, my pending changelists, and whether each is shelved
---

# Perforce Status

Read-only overview of the workspace, in Japanese.

## Steps

```bash
bash .claude/vendor/p4-harness/scripts/p4-connect.sh
p4 -p "$P4_PROXY" opened
p4 -p "$P4_PROXY" changes -s pending -u "$P4USER" -c "$P4CLIENT"
```

(If `P4USER` / `P4CLIENT` are unset, drop the `-u` / `-c` filters and note that the list may
include other users' changelists.)

For each pending CL, run `p4 -p "$P4_PROXY" describe -S -s N` and check whether it lists
`Shelved files:`.

## Output

```
開いているファイル
  default   (2 件)  ← 説明文の無い default CL。/p4-shelve default で CL にまとめられます
    edit  //depot/.../A.cpp
    add   //depot/.../B.h
  CL 12345  fix: ...   (3 件, シェルブ済み)
    edit  //depot/.../C.cpp
    ...

保留 CL
  12345  fix: ...          シェルブ済み  → /review-cl 12345
  12350  feat: ...         未シェルブ    → /p4-shelve 12350
```

End with the suggested next command for each CL. Never modify anything from this command.
