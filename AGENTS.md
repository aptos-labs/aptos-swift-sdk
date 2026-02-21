# AGENTS.md

Shared execution rules for automated coding agents working in this repository.

## 1) PR body format is mandatory

Use `.github/pull_request_template.md` and keep every section.

Minimum required sections:

- Summary
- Motivation
- Changes
- Testing
- Format & Lint
- Checklist

## 2) Formatting and lint are blocking checks

Before pushing, run:

```bash
make format
make format-check
make lint
swift test
```

`make format-check` and `make lint` must be clean. Do not rely on reviewers to fix style failures.

## 3) Fast feedback loop for CI failures

If CI fails:

1. Inspect logs (`gh run view --log-failed`).
2. Patch only reported files first.
3. Re-run formatting/lint checks.
4. Push a focused follow-up commit.

## 4) Style pitfalls seen in this codebase

- Remove unnecessary `throws` in test declarations.
- Avoid force unwraps.
- Keep braces/wrapping consistent with `.swiftformat`.
- Keep computed property body style formatter-compatible.
- Keep numeric literal grouping consistent.

## 5) Completion criteria

A change is complete only when:

- CI is green for Build/Test, Format Check, and SwiftLint.
- PR description follows the required template.
