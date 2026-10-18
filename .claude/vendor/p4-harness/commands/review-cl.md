---
description: Cross-review a shelved Perforce changelist in this (separate) session using the review agents
argument-hint: "<CL number> [--focus=correctness|impact|errors|standards|comments|performance|simplicity|tests]"
---

# Review Changelist

> Perforce counterpart of `/review-pr`. Runs the `p4-cl-cross-review` skill.

**Input**: $ARGUMENTS

## Usage

`/review-cl <CL number> [--focus=correctness|impact|errors|standards|comments|performance|simplicity|tests]`

Run this in a **new session**, not in the session that wrote the change — the separation is what
makes the review independent.

## Steps

1. Validate the argument: a positive integer is required. If missing, print the usage above and
   stop.
2. Invoke the skill `p4-cl-cross-review` with the changelist number (and the focus, if given).
   The skill fetches the shelved diff through `scripts/p4-describe.sh`, runs the review agents
   independently and in parallel, verifies the findings against the diff, and saves a Japanese
   report.
3. Present the skill's chat summary: report path, counts by severity, and every CRITICAL / HIGH
   finding in one line.

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

Only findings with confidence >= 80 are reported, following the agents' own gates. A clean CL is
a valid result — do not manufacture findings.
