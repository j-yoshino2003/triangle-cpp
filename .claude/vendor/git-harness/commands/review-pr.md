---
description: Cross-review a pull request, a branch, or the working tree against the base branch (develop) using the review agents, and save a Japanese report under docs/reviews/
argument-hint: "[PR number | branch | working] [--base=develop] [--focus=correctness|impact|errors|standards|comments|performance|simplicity|tests]"
---

# Review Pull Request

> Runs the `git-pr-cross-review` skill.

**Input**: $ARGUMENTS

## Usage

`/review-pr [<PR number> | <branch> | working] [--base=develop] [--focus=correctness|impact|errors|standards|comments|performance|simplicity|tests]`

Run this in a **new session**, not in the session that wrote the change — the separation is what
makes the review independent. `working` reviews the current checkout including uncommitted and
untracked changes, so a change can be reviewed before it is committed or pushed.

If no target is given, review the current branch's open PR when `gh` finds one, otherwise
`working`. The base branch is `develop` unless `--base` says otherwise.

## Steps

1. Validate the argument: a positive integer, an existing branch name, `working`, or nothing.
   Anything else → print the usage above and stop.
2. Invoke the skill `git-pr-cross-review` with the target, the base, and the focus (if given).
   The skill fetches the diff through `scripts/review-target.sh`, runs the review agents
   independently and in parallel, verifies the findings against the diff, and saves a Japanese
   report under `docs/reviews/`.
3. Present the skill's chat summary: report path, counts by severity, the verdict
   (APPROVE / WARNING / BLOCK), and every CRITICAL / HIGH finding in one line.

## Focus

Without `--focus`, the full stack runs: `code-reviewer`, `impact-scope-reviewer`,
`silent-failure-hunter`, `coding-standards-reviewer`, `comment-analyzer`, `performance-reviewer`,
`simplicity-reviewer`. With a focus, only that agent runs:

| Focus | Agent |
|-------|-------|
| `correctness` | `code-reviewer` |
| `impact` | `impact-scope-reviewer` |
| `errors` | `silent-failure-hunter` |
| `standards` | `coding-standards-reviewer` |
| `comments` | `comment-analyzer` |
| `performance` | `performance-reviewer` |
| `simplicity` | `simplicity-reviewer` |
| `tests` | `pr-test-analyzer` |

## Confidence Rule

Only findings with confidence >= 80 are reported, following the agents' own gates. A clean change
is a valid result — do not manufacture findings.
