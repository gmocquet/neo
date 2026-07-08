# AGENTS.md — directives for AI coding agents

## Project Context

- `neo` is the central, versioned home for AI coding-agent assets — skills
  (under `skills/`) and hooks acting as guardrails (under `hooks/`), with more
  helpers over time — installed at the user level of the coding agent: skills are
  symlinked into `~/.claude/skills` by `make skills-link`, hooks are registered in
  `~/.claude/settings.json` by `make hooks-add`.
- This repository is **public**: never commit secrets, credentials, or private
  data of any kind. This rule is enforced by the `no-secrets-on-commit` guardrail
  (`hooks/no-secrets-on-commit/`), a `PreToolUse` hook that runs gitleaks on the
  staged changes before any `git commit` and blocks the commit on detection.
- Repo: the git repo is rooted at the directory containing this file; skill work
  happens here, and Claude Code consumes the skills from `~/.claude/skills` via
  symlinks. Remote: `github.com:gmocquet/neo.git`, branch `main`, direct commits
  (no PRs required for this personal repo).
- Use the GitHub CLI (`gh`) to automate updates on this repo: create commits and
  PRs following conventional commits, and merge those PRs yourself once checks
  pass — self-merge is allowed here (this overrides the global "never merge"
  guardrail for this repository only).

## Coding Guidelines

- Keep changes simple and readable; follow DRY, KISS, and YAGNI.
- Add tests for all new features and bug fixes.
- Don't add inline comments unless it's needed or you have been asked to.
- Avoid imports inside functions unless necessary.

## Commit Message Guidelines

- Use conventional commit format: `<type>(<scope>): <subject>`.
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
- Scope: optional, can be the name of the module or component affected.
- Subject: brief description of the change.

## AI Settings

- **NEVER add AI attribution to commits** (no `Co-Authored-By: Claude`, no
  "Generated with"). This preference is also stored in persistent memory. It is
  enforced by the `no-ai-attribution-on-commit` guardrail
  (`hooks/no-ai-attribution-on-commit/`), which blocks `git commit` and
  `gh pr create/edit` commands carrying such an attribution.
