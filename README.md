# neo

Agentic Engineering — Disciplined Assistant Agent System for EMs and Developers

## What is neo?

`neo` is the central, versioned home for the assets that power my agentic coding
tools — primarily [Claude Code](https://claude.com/claude-code). Today it stores
**skills** (reusable agent capabilities) and **hooks** (deterministic guardrails
around tool calls); over time it will grow into more AI helpers.

Everything here is designed to be installed at the **user level** of the coding
agent (`~/.claude` for Claude Code), so the assets are available in every project
you work on — not per-repository: skills are symlinked into `~/.claude/skills`,
hooks are registered in `~/.claude/settings.json`. Any agent that supports the
same skill format (Claude Code, Codex, ...) can consume the skills.

## Who is it for?

- **Developers** using an agentic coding assistant day to day: codebase analysis,
  review reports, PR authoring.
- **Engineering Managers** — notably those hiring tech profiles such as Data
  Engineers or Platform Engineers: several skills analyze take-home assignment submissions and generate
  automated, scored review reports.

## What you will find

```
neo/
├── AGENTS.md         # directives for AI coding agents working on this repo
├── Makefile          # `make skills-link` — install the skills into ~/.claude/skills
├── .github/
│   └── repo-settings/  # GitHub repo configuration as code (export / apply)
├── hooks/            # Claude Code hooks — deterministic guardrails
│   └── no-secrets-on-commit/
└── skills/           # Claude Code skills (user scope)
    ├── ask-questions-about-codebase/
    ├── create-review-about-codebase/
    ├── neo-challenge-review/
    └── pr-writer/
```

### Skills catalog

| Skill                          | Audience          | What it does                                                                                                                                                                                                                                                            |
| ------------------------------ | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `neo-challenge-review`         | EMs / hiring managers | Critical, scored review of a candidate's take-home tech-challenge submission. Fans out one agent per indicator (DevEx, AI usage rate & quality, security, production readiness, automation, tests, challenge coverage, runability), optionally builds blind AI baseline implementations to separate candidate contributions from AI contributions, and produces a scored report with a radar chart plus 10 interview questions. Depth is tunable: `analyze`, `run`, or `benchmark`. |
| `ask-questions-about-codebase` | Developers & EMs  | Analyzes a codebase and generates critical questions about architecture decisions, project structure, local development setup, and engineering best practices. Focused on Python and Infrastructure as Code (Terraform/OpenTofu) projects.                               |
| `create-review-about-codebase` | Developers & EMs  | Companion of `ask-questions-about-codebase`: combines the generated questions with your manual notes (`.data/my-notes.md`) into a final codebase review report.                                                                                                          |
| `pr-writer`                    | Developers        | Creates and updates GitHub pull requests (via the `gh` CLI) with consistent titles, descriptions, and issue references.                                                                                                                                                  |

### Hooks catalog

Hooks are deterministic guardrails: unlike an instruction in `AGENTS.md` (which the
model can forget or misapply), a hook is a script the Claude Code harness runs on
every matching tool call — its verdict is enforced, not suggested.

| Hook                   | Event               | What it does                                                                                                                                                                                                                                 |
| ---------------------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `no-secrets-on-commit` | `PreToolUse` (Bash) | Blocks any agent `git commit` when [gitleaks](https://gitleaks.io) finds a secret in the staged changes (fail-closed if gitleaks is missing). Known-fake credentials can be allowlisted per repo via `.gitleaks.toml` or a `gitleaks:allow` comment. |
| `no-ai-attribution-on-commit` | `PreToolUse` (Bash) | Blocks `git commit` and `gh pr create/edit` commands whose message or description carries an AI attribution (`Co-Authored-By: Claude`, "Generated with Claude Code", "Powered by Claude", ...). A plain mention of Claude Code in a message is not affected. |

## Getting started

### Prerequisites

Install instructions are provided per OS (Linux and Windows will come later).

#### macOS

| Requirement                                        | Description                                                                             | Install command                |
| -------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------ |
| [Homebrew](https://brew.sh)                         | macOS package manager used to install the requirements below                            | see [brew.sh](https://brew.sh) |
| [Claude Code](https://claude.com/claude-code)       | The coding agent that discovers and runs the skills (any skill-capable agent works)      | `brew install --cask claude-code` |
| [`git`](https://git-scm.com)                        | Clones and updates this repository                                                      | `brew install git`             |
| `make`                                              | Runs the install targets (`make skills-link` / `make skills-unlink`); ships with the Xcode Command Line Tools | `xcode-select --install`  |
| [GitHub CLI](https://cli.github.com) (`gh`)         | Drives GitHub from the terminal — required by the `pr-writer` skill and the automated commit/PR workflow | `brew install gh` |
| [`gitleaks`](https://gitleaks.io)                   | Secret scanner — required by the `no-secrets-on-commit` hook (which fails closed without it) | `brew install gitleaks`   |
| [`jq`](https://jqlang.org)                          | JSON processor — used by the hooks to parse the tool-call input and by `make hooks-add` / `make hooks-remove` to edit the settings file | `brew install jq` |
| [`pre-commit`](https://pre-commit.com)              | Git hooks manager — runs this repository's `.pre-commit-config.yaml` checks (contributors only) | `brew install pre-commit`      |
| [`uv`](https://docs.astral.sh/uv/)                  | Python toolchain — runs the repo-settings automation (installs its pinned Python and deps) | `brew install uv`              |

### Install

Skills must live in the agent's user-level skills directory (`~/.claude/skills`
for Claude Code). The `skills-link` target symlinks every skill from this repository
into that directory:

```bash
git clone git@github.com:gmocquet/neo.git
cd neo
make skills-link
```

Because the skills are **symlinked** (not copied):

- `git pull` updates every installed skill in place — no re-install step;
- any local edit in this repository is live in the agent immediately.

After adding or updating skills, reload them in your coding agent so it picks up
the changes (`/reload-skills` in Claude Code); new sessions load them automatically.

`make skills-link` is idempotent and safe: it refreshes existing symlinks, but never
overwrites a real file or directory already present in `~/.claude/skills` — it
skips it and warns you so you can resolve the conflict manually.

### Verify

```bash
ls -l ~/.claude/skills
```

Then start Claude Code and type `/` — the skills appear in the command list
(e.g. `/neo-challenge-review`). You can also run `/skills` to list every skill
Claude Code has picked up: if everything is OK, all the skills of this
repository are listed there.

### Enable the git hooks (contributors)

The repository ships a [pre-commit](https://pre-commit.com) configuration
(YAML/JSON sanity checks, whitespace and line-ending hygiene, GitHub Actions
workflow linting). If you contribute to this repository, install the git hooks
once:

```bash
pre-commit install
```

### Enable the hooks

Unlike skills, hooks are not discovered from a directory: they are registered in
Claude Code settings — `~/.claude/settings.json` (user scope, so the guardrails
protect **every** repository you work on):

```bash
make hooks-add     # register every hook of this repo
make hooks-remove  # unregister exactly those hooks
```

Both targets edit the settings file surgically with `jq` (each hook declares
itself in a `hook.json` manifest): the file is created if missing, the rest of
your configuration is never touched, `hooks-add` is idempotent, and
`hooks-remove` only deletes entries pointing into this repository. The target
file can be overridden with `CLAUDE_SETTINGS_FILE=/path/to/settings.json`.

Hooks are loaded at session startup: restart Claude Code (or start a new session)
for the registration to take effect. To check the hooks themselves, run their
test suites:

```bash
bash hooks/no-secrets-on-commit/tests.sh
bash hooks/no-ai-attribution-on-commit/tests.sh
bash hooks/hooks-config-tests.sh
```

### Use another agent or target directory

The destination is overridable, so the same repository can serve any agent that
discovers user-level skills from a directory:

```bash
CLAUDE_SKILLS_DIR=/path/to/your/agent/skills make skills-link
```

### Uninstall

Remove the symlinks installed by `make skills-link` — the repository copies are untouched:

```bash
make skills-unlink
```

`make skills-unlink` is as careful as `make skills-link`: it only removes symlinks that point
into this repository, and leaves anything else in `~/.claude/skills` alone.

## Repository settings as code

The repository's GitHub configuration — core settings/features, rulesets, and
outside collaborators — is versioned under `.github/repo-settings/settings.json`
and validated against `repo-settings.schema.json`. This makes the repo
reproducible: the whole configuration can be re-applied to a fresh repo. The
engine is a small [uv](https://docs.astral.sh/uv/) project
(`.github/repo-settings/`) driving the GitHub API through `gh`.

```bash
make repo-settings-export    # live repo -> settings.json (manual; run when you change config in the UI)
make repo-settings-validate  # validate settings.json against the schema
make repo-settings-diff      # show drift between settings.json and the live repo (check before pushing)
make repo-settings-apply     # settings.json -> live repo
```

Target another repo with `make repo-settings-diff REPO=owner/name`.

**GitOps** — pushes touching `.github/repo-settings/**` trigger
`.github/workflows/repo-settings.yml`: on a **non-`main` branch** the CI reports
the drift (a preview of what merging will change); on **`main`** it applies
`settings.json` to the repo. The **export stays manual**.

The CI needs a repository secret **`REPO_SETTINGS_TOKEN`**: a fine-grained PAT
scoped to this repo with the **Administration** permission (read for `diff`,
read/write for `apply`) — the built-in `GITHUB_TOKEN` cannot be granted the
Administration permission, so it cannot read or write rulesets. Until the secret
is configured, the CI job **fails** with an explicit error.

To configure it, run:

```bash
make repo-settings-token-set
```

This token lets the CI apply neo's GitHub configuration (settings, rulesets,
access) as code. **neo** is the central, versioned home for AI coding-agent assets
(skills, hooks); the token's scope is **Administration read/write on this
repository only**.

`make repo-settings-token-set` opens a [pre-filled fine-grained PAT page](https://github.com/settings/personal-access-tokens/new?name=neo-repo-settings&description=CI%20token%20for%20the%20neo%20repository%2C%20the%20central%20versioned%20home%20for%20AI%20coding-agent%20assets%20such%20as%20skills%20and%20hooks.%20Used%20by%20the%20repo-settings%20GitHub%20Actions%20workflow%20to%20apply%20the%20repository%20configuration%20%28settings%2C%20rulesets%2C%20and%20access%29%20as%20code.%20Scope%3A%20Administration%20read%20and%20write%20on%20neo%20only.&target_name=gmocquet&expires_in=none&administration=write)
(token name, description, *No expiration*, and *Administration: Read and write*
are already set via URL parameters), waits for you to generate and copy the token,
then stores it as the `REPO_SETTINGS_TOKEN` secret (the value is prompted, never
passed as an argument). The only field left to fill is **Repository access → Only
select repositories → your repo** — GitHub has no URL parameter for repository
selection, so this restriction is the one manual step.

Once the secret is stored, finish with:

1. Confirm it: `make repo-settings-token-status`.
2. Preview what the CI will report: `make repo-settings-diff`.
3. Re-run the previously failing `repo-settings` check on your PR (or push again) —
   it passes now that the token is present.
4. Merge the PR: on the `main` branch the CI applies `settings.json` to the repo.

Other helpers:

```bash
make repo-settings-token-status  # report whether the secret exists
make repo-settings-token-delete  # remove the secret
```

Generating the PAT is the only manual step (GitHub has no API to mint PATs); the
storage is scripted for reproducibility.

## Roadmap

- **Hooks & guardrails** — first one shipped (`no-secrets-on-commit`); more reusable
  hooks around tool calls and agent lifecycle, and more safety policies, to come
- More helpers and AI features as they prove useful across projects
