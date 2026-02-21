# CLAUDE.md

Repository-specific guidance for Claude-based coding agents.

## PR format requirements

Use `.github/pull_request_template.md` for every PR description. Keep all sections:

1. Summary
2. Motivation
3. Changes
4. Testing
5. Format & Lint
6. Checklist

Do not submit a PR with missing sections.

## Required quality gates before push

Run these commands locally before pushing:

```bash
make format
make format-check
make lint
swift test
```

If `swift` tooling is unavailable in the local environment, clearly state that in your final update and verify status via GitHub Actions.

## SwiftFormat/SwiftLint expectations

The CI pipeline enforces both formatting and linting. Common failure patterns to avoid:

- `redundantThrows`: do not mark test functions `throws` unless needed.
- `braces`: keep K&R style (`} else {`) and place opening braces per `.swiftformat`.
- `wrapPropertyBodies`: use multi-line computed property bodies when required by formatter.
- `numberFormatting`: keep numeric separator style consistent with formatter output.
- `redundantReturn`: omit unnecessary `return`.

## Definition of done for agent changes

- Code compiles and tests pass in CI.
- `Format Check` and `SwiftLint` checks are green.
- PR body follows template exactly.
