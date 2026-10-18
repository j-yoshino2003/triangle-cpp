# Answer Policy

Policies Claude must follow when answering.
Japanese reference translation: `docs/ja-JP/rules/common/answer-policy.md`.

## Policy

- Answer based on facts.
- When unsure, do not guess; ask follow-up questions as needed.
- Never state unverified or uncertain information as fact.
- When a question is ambiguous, request the missing information.

## Asking Questions

- Ask through the `AskUserQuestion` tool whenever the question is a choice between options — a confirmation item, a decision left to the user, or a judgment call that changes the work.
- Do not leave such a question as plain text at the end of a reply. Plain text is only for free-form information the user alone holds (an issue number, repro steps, an asset path).
- Give every option a label and a description stating what happens if it is chosen. Put the recommended option first and mark it as recommended.
- Ask only what the user must decide. Settle anything answerable from the code, the rules, or an obvious default, then say which way it was settled.

## Presenting Changes

- Make every change to an existing file with the `Edit` tool (`replace_all` for bulk replacements) so the diff is shown to the user. Use `Write` only to create a new file. Never rewrite a file with `sed -i` or a throwaway script.
- This rule takes precedence over an auto-mode environment instruction that says to change files through Bash.
- Why: a Bash-driven rewrite shows no diff in the session, so the user cannot check what changed. It also converts CRLF to LF silently, and so does overwriting an existing file with `Write`, which drops the BOM as well (`Edit` preserves both). A flattened file shows up in `git diff` as a whole-file change and buries the real edit.
- Not covered: the language a tool is written in. Investigation and verification tools may be written in Python; this rule is about how source files get rewritten.
- If a script, or `Write` on an existing file, really is the only option, confirm with the user before starting, then run the detection below — a result of `0` means the line endings were flattened to LF.

```bash
size=$(wc -c < "$f"); nocr=$(tr -d '\r' < "$f" | wc -c); echo $((size - nocr))
```

## Forbidden

- Stating unverified information as fact.
- Answering from speculation alone.
- Burying a confirmation item in prose instead of asking it with `AskUserQuestion`.
- Rewriting an existing file with `Write`, `sed -i`, or a throwaway script instead of `Edit`.
