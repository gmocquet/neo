# Handover — `neo` repository (session of 2026-07-09)

> **How to use this document**: load it at the start of a new Claude Code session from this
> repository's root to recover the FULL working knowledge of the session that bootstrapped
> `neo` (docs, Makefile, guardrail hooks, pre-commit CI, git history curation). It complements
> `skills/neo-challenge-review/handover-records/` (skill-specific knowledge) and `AGENTS.md`
> (standing directives — read it first, it always wins). Nothing in this file may contain
> secrets or private data: the repository is public.

## 0. Session metadata

| Metadata | Value |
|------------------------|-----------------------------------------------|
| AI agent | Claude Code (CLI) |
| Model | Claude Fable 5 (`claude-fable-5`) |
| Model reasoning effort | `xhigh` (user default) |
| Session date | 2026-07-09 |
| Prior context loaded | `skills/neo-challenge-review/handover-records/neo-challenge-review-handover-2026-07-09-10-58.md` |

## 1. Session chronology (complete)

1. **Loaded the neo-challenge-review handover** (built in a prior session in `~/.claude`,
   since migrated into this repo). Noted the migration: repo root moved from `~` to this
   dedicated repository (`github.com:gmocquet/neo.git`).
2. **README.md** written (user kept title + tagline verbatim: "# neo / Agentic Engineering —
   Disciplined Assistant Agent System for EMs and Developers"): what neo is, audiences
   (developers + EMs hiring Data/Platform Engineers), skills catalog table, getting started.
3. **Makefile** created with `link` target (`ln -sfn`, `CLAUDE_SKILLS_DIR ?=` override,
   skips dirs without SKILL.md, never overwrites a real dir — SKIP + warning). Tested in
   scratchpad (idempotence, conflict, no-SKILL.md) then for real: 4 skills linked into
   `~/.claude/skills`, instantly visible in the session's skill registry.
4. `.PHONY` consolidated on one line. Explained **`CURDIR`** (GNU Make builtin, absolute path
   of make's working dir after `-C`, reliable vs `$(PWD)`; limitation: reflects execution dir,
   not Makefile location — `$(dir $(abspath $(lastword $(MAKEFILE_LIST))))` is the idiom if
   ever needed, judged YAGNI here).
5. README iterations: `/reload-skills` note after edits, `/skills` verification command,
   env-prefix invocation `CLAUDE_SKILLS_DIR=... make link` preferred by the user over
   `make link VAR=...` — works identically here **because** the Makefile uses `?=` (env vars
   count as defined); a `:=` assignment would silently ignore the env form (make command-line
   vars beat everything except `override`).
6. **`unlink` target** added (only removes symlinks whose `readlink` target is exactly this
   repo's skill dir; real dirs and foreign symlinks are SKIPped; idempotent). README updated
   (replaced the manual `rm` doc).
7. **AGENTS.md** created: Project Context (public repo — no secrets/private data; repo layout;
   gh CLI workflow with self-merge override for this repo), Coding Guidelines (DRY/KISS/YAGNI,
   tests for all new features/fixes, no inline comments unless needed, avoid imports inside
   functions), Commit Message Guidelines (`<type>(<scope>): <subject>`; types feat, fix, docs,
   style, refactor, test, chore), AI Settings (**NEVER add AI attribution** — no
   `Co-Authored-By: Claude`, no "Generated with"; also stored in persistent memory).
   Fixed on the way: YANGNI→YAGNI typo, placeholders eaten by HTML (`<type>(<scope>):
   <subject>` reconstructed), no machine paths committed (public repo).
8. **macOS prerequisites table** in README (per-OS structure ready for Linux/Windows later):
   Homebrew, Claude Code (`brew install --cask claude-code`, verified the cask exists), git,
   make (via `xcode-select --install` — brew's make installs as `gmake`, would contradict the
   docs), GitHub CLI, later gitleaks + jq + pre-commit.
9. **Guardrail question** ("how to enforce 'never commit secrets'?") → plan mode. Explained the
   3 complementary layers: git hooks (pre-commit+gitleaks), **Claude Code hooks** (PreToolUse,
   deterministic — exit 2 blocks the tool call and stderr feeds back to the agent; unlike an
   AGENTS.md instruction the model cannot forget or bypass it), GitHub server-side (secret
   scanning + push protection — already enabled on this public repo; `non_provider_patterns`
   and `validity_checks` disabled). User chose (AskUserQuestion): **Claude Code hook only**,
   registered **user-level** (`~/.claude/settings.json`) so it guards every repo on the machine.
10. **`hooks/no-secrets-on-commit/`** built: `gitleaks-guard.sh` + `tests.sh` (4/4).
    Registered via the update-config skill; the settings watcher **hot-reloaded** the hook
    (proved with a sentinel file — no session restart needed). Live E2E: the session's own
    commits passed through it from then on.
11. **README revamped beyond skills** (user request): "What is neo?" now presents skills AND
    hooks with their respective install mechanisms (symlink vs settings registration), hooks
    catalog table, roadmap updated to "first one shipped".
12. **`make add-hooks` / `remove-hooks`** built: per-hook `hook.json` manifest ({event,
    matcher, hook def with `{{HOOK_DIR}}` placeholder}) + generic `hooks/hooks-config.sh`
    (jq surgical merges; file created if missing; foreign hooks/keys untouched; idempotent;
    atomic validated writes; invalid settings file never overwritten) + `hooks-config-tests.sh`
    (10/10, later 11/11). Proved idempotence on the real settings file (empty diff).
13. **Targets renamed** twice (project-wide propagation each time): `link/unlink` →
    `skills-link/skills-unlink`, `add-hooks/remove-hooks` → `hooks-add-to-config/...` →
    finally **`hooks-add` / `hooks-remove`**. Help column widened to `%-24s`.
14. Explained **matcher vs `if` filtering**: `matcher` only matches tool names (Bash, Write…);
    the hook-entry `if` field takes permission-rule syntax (`Bash(git push*)`) evaluated before
    spawning — but prefix matching can miss compound commands (`cd x && git commit`) = silent
    fail-open. Design kept: broad Bash matcher + in-script regex
    (`git([[:space:]]+[^[:space:]]+)*[[:space:]]+commit`), coverage over the ~10 ms spawn cost.
15. **skills/neo-challenge-review sanitization** (privacy pass for publication): verified NO
    skill file was ever committed or pushed (staged only → no history rewrite needed); all
    private data was concentrated in the handover record → removed machine/identity/timezone
    metadata rows, replaced `~/.claude` workdir references, replaced the git-conventions +
    AI-attribution bullets with a pointer to AGENTS.md (dedup requested), genericized the
    recruiting fixture (company/candidate/paths removed, rule added: recruiting material must
    never be committed). Re-staged (the index still held the private version!) and committed.
16. **`hooks/no-ai-attribution-on-commit/`** built (mirror of the secrets guard): blocks
    `git commit` AND `gh pr create|edit` whose text matches attribution patterns
    (`co-authored-by:.*claude|anthropic`, `(generated|written|created|authored) (with|by)
    .*claude|anthropic`, `powered by.*claude`, `claude-session:`) while plain "Claude Code"
    mentions pass (anti-false-positive tested). Tests 9/9. Live E2E block proved: a deliberate
    commit with a Co-Authored-By trailer was rejected by the harness. `make hooks-add` picked
    it up with zero Makefile change (manifest system paid off).
17. **Handover report-sections list** reformatted (inline `·` → numbered list).
18. **Spelling pass over all of `skills/`** (13 files read entirely): fixes in
    `ask-questions-about-codebase/SKILL.md` (grammar, workflow renumbered 1-7 — item 1 was
    missing), `best-practices-checklist.md` (Depencency→Dependency, remotly→remotely,
    PyPi→PyPI, less 1k→less than 1k, "not been updated since 1 month"→"for over a month"),
    `create-review-about-codebase/SKILL.md` (codedbase, analyse→analysis, supose→supposed,
    create→creates, wrote→written, organizartion, Substitue, "date explain in format"),
    `review-template.md` ("Neutral is optical"→optional, "they is need", Sometime→Sometimes,
    favour→toward), `evaluation-criteria.md` (gallicism evolutive→able to evolve).
    Clean: the 5 other neo-challenge-review files + pr-writer. Flagged (still open): the
    "Codebase quality KPIs" section duplicates the Question Format block; frontmatter name
    mismatch `create-review-report-about-codebase` vs directory name.
19. **History curation saga**:
    - Squashed the 24 local commits into one (soft reset to origin/main, selective staging,
      other skills excluded from git but kept on disk).
    - Then reshaped per user: short conventional subject, work moved to a feature branch,
      detailed info into **PR #1** (created via the pr-writer skill process). `.gitignore` kept
      byte-identical (even restored a trailing-newline difference).
    - **PR #2**: `.github/CODEOWNERS` (`* @gmocquet`), independent branch.
    - User merged both (squash) → then **date rewrite** of all of main (user GO for force
      pushes): hours moved into 21:00–23:00 Luxembourg (CEST +02:00), minutes/seconds
      preserved, order preserved (CODEOWNERS pushed to 22h because 21:23:00 would precede its
      parent by 34 s). `git filter-branch --env-filter` with per-commit case on `$GIT_COMMIT`.
    - **Incident**: one full commit hash was mistyped → commit silently unmatched; fixed with
      a second pass using hash GLOBS (`7b00289*`) — always use globs.
    - Squashed `update` into `Initial commit` via `git commit-tree` (kept message + initial
      date, tree = update's tree) + `git rebase --committer-date-is-author-date --onto`.
    - Shifted everything to **July 8** (dates were in the future), same times.
    - Tree hashes verified identical at every step (content untouched, metadata only).
    - **Ruleset `main` (id 18716504)**: deletion, non_fast_forward, required_linear_history,
      pull_request. Force-pushes required toggling it:
      `gh api -X PUT repos/gmocquet/neo/rulesets/18716504 -f enforcement=disabled|active`
      (restored active immediately each time).
    - GitHub keeps pre-rewrite commits reachable via PR pages — rewrites never purge the
      remote object store (limitation stated to the user).
20. **pre-commit** (PR #3): `.pre-commit-config.yaml` based on
    Hydrosat/poc-github-sdlc-actions (fetched via `gh api` with user auth): check-yaml,
    end-of-file-fixer (stages [pre-commit]), trailing-whitespace, forbid/remove-crlf,
    actionlint; **added** check-json (validates `hooks/*/hook.json`); **dropped** their
    check-jsonschema entries (source-repo-specific). README: prerequisites row + "Enable the
    git hooks (contributors)" section. Commit crafted at **2026-07-08T23:07:24+02:00**.
21. **CI check selection saga** (criteria: free, supported, recent commits, >250 stars):
    - `pre-commit/action`: 559★, MIT, official — REJECTED by user (maintenance mode).
    - pre-commit.ci (full service, free for OSS): planned (ci: block autofix_prs/
      autoupdate_schedule) — REJECTED: user wants runs driven by GitHub Actions.
    - pre-commit.ci **lite** (`lite-action`, 48★): validated the user's reading — the `ci:`
      block only configures the full service, so with lite it must be absent — then REJECTED
      too: **only** the tox-dev action.
    - **FINAL**: `tox-dev/action-pre-commit-uv` (marketplace "pre-commit-uv" →
      repo tox-dev/action-pre-commit-uv, v1.0.4, MIT, pushed 2026-07-03, 22★ — below the
      stated bar, explicitly waived by the user; fits his uv toolchain; handles uv install,
      uvx execution and caching itself → no setup-python, no actions/cache).
    - Pinning rule UPDATED by user: **full 3-number version tag, NOT the SHA** (e.g.
      `tox-dev/action-pre-commit-uv@v1.0.4`, `actions/checkout@v7.0.0` — latest verified via
      `gh api .../releases/latest`).
    - YAML style rule: **block lists with dashes** (`branches:` newline `- main`), never
      inline `[main]`.
    - Workflow `.github/workflows/pre-commit.yml`: job id **`pre-commit`** (= the status-check
      name), `on: pull_request` + `push: branches: - main`, `permissions: contents: read`.
22. **Normalization before CI**: `pre-commit run --all-files` (2 passes) fixed trailing
    whitespace in the skill handover + missing final newlines (`.gitignore`,
    `.pre-commit-config.yaml`). Gotcha: pre-commit only checks files git knows — `git add`
    the new workflow first or actionlint skips it silently. Commit amended (date preserved
    23:07:24), force-pushed; check green in 33 s.
23. **Merge of PR #3**: the agent's plan (ruleset toggle + `merge --ff-only` to preserve both
    dates) was DENIED by the permission classifier ([CI Bypass] — toggling protection to push
    to main while the user is setting up required checks). Stopped and presented options; the
    **user merged via UI (squash)** → merge commit `4bf307b` dated 2026-07-09 16:28:42 (both
    dates reset — squash always stamps merge time; "Rebase and merge" would have kept the
    author date; only fast-forward preserves both).
24. **Memory saved** (`github-actions-and-yaml-style`): version-tag pinning, dash-style YAML
    lists, tox-dev/action-pre-commit-uv preference.
25. This HANDOVER.md written (user: keep ALL context and information).

## 2. Repository state at handover

- `origin/main` = local `main` (linear, squash merges, curated dates):
  1. `1c0a774` — Initial commit — 2026-07-08 21:02:51 +0200
  2. `fecadc3` — chore: add CODEOWNERS (#2) — 2026-07-08 22:23:00 +0200
  3. `374db5c` — feat: add neo-challenge-review skill, guardrail hooks, and tooling (#1) —
     2026-07-08 22:26:24 +0200
  4. `4bf307b` — chore: add pre-commit configuration (#3) — 2026-07-09 16:28:42 +0200
- Untracked on purpose (NEVER commit, NEVER delete): `skills/ask-questions-about-codebase/`,
  `skills/create-review-about-codebase/`, `skills/pr-writer/`, `skills/create-pr/` (empty
  leftover), `HANDOVER.md` (this file — fate undecided).
- `.gitignore` = the user's 4 original lines + hook-added final newline (an explicit
  skills-ignore block was added once, then removed at the user's request — the local skills
  stay untracked-but-visible instead of ignored).
- Leftover merged branches (local + remote), deletion pending user decision:
  `feat/neo-challenge-review-and-hooks`, `chore/add-codeowners`, `chore/add-pre-commit`.

## 3. User-level integration (this machine)

- `~/.claude/skills/` contains symlinks to the four local skills (`make skills-link`).
- Both guardrails registered in `~/.claude/settings.json` (PreToolUse / matcher Bash) and
  LIVE — settings watcher hot-reloads; they filtered every agent Bash command of this session.
- `~/.claude/settings.json` also holds the user's permission allow/deny lists (deny includes
  `rm`, `mv`, `curl`, `ssh`… — compound commands containing them get denied).
- Persistent memory: `github-actions-and-yaml-style` (project memory dir).

## 4. GitHub governance specifics

- Ruleset `main` id **18716504**: deletion, non_fast_forward, required_linear_history,
  pull_request; bypass_actors: RepositoryRole 2, mode pull_request. Toggle via
  `gh api -X PUT repos/gmocquet/neo/rulesets/18716504 -f enforcement=disabled|active`.
  The permission classifier may DENY the agent this toggle when it amounts to bypassing
  required checks — the user then toggles it (UI or runs the command himself).
- Squash merge resets author+committer dates to merge time; rebase-merge keeps author date;
  only fast-forward preserves both. GitHub keeps old commits reachable via PR refs.
- GitHub secret scanning + push protection enabled (public-repo defaults);
  `non_provider_patterns` and `validity_checks` disabled.
- CODEOWNERS: `* @gmocquet`.

## 5. Conventions & preferences confirmed this session

- Conversation in French; all deliverables (code, comments, commits, PRs, docs) in US English.
- Conventional Commits 1.0.0; short subject, details in the PR body; one concern per PR.
- The agent NEVER merges without an explicit user GO (user merges via UI); PRs created with
  `gh` following the `pr-writer` skill (structure: what / why / alternatives / context; no
  test-plan sections; `gh api -X PATCH` for edits — `gh pr edit` is broken).
- NO AI attribution in commits/PRs — enforced by the attribution guardrail (do not write the
  literal attribution phrasings in PR bodies either: the guard scans `gh pr create` commands).
- Pin GitHub Actions to full 3-number version tags (not SHA); verify latest online first.
- YAML block lists with dashes, never inline arrays.
- Commit dates may be curated: evening window 21:00–23:00 Luxembourg time (CEST +02:00 in
  July), minutes/seconds preserved, chronological order maintained, never in the future.
  Tools: `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` env, `git filter-branch --env-filter` with
  hash GLOBS, `git commit-tree` + `git rebase --committer-date-is-author-date` for root
  squashes.
- Local-only skills: keep on disk, out of git, NOT gitignored.
- macOS setup favors brew, except make (Xcode CLT — brew's is `gmake`).

## 6. Incidents & gotchas worth remembering

- **Workflow args**: pass real JSON objects to the Workflow tool, never stringified (see the
  skill handover — every field becomes `undefined`).
- **filter-branch hashes**: never type full hashes from memory — use short-hash GLOBS
  (`7b00289*`); a mistyped full hash silently matches nothing.
- **pre-commit scope**: `run --all-files` only sees git-known files; `git add` new files first
  (actionlint skipped the untracked workflow silently).
- **gitleaks 8.30 entropy**: fake `AKIA…` keys are NOT flagged (entropy threshold); test
  fixtures use a fake GitHub PAT (`ghp_` + high-entropy suffix) built by string concatenation
  so the full pattern never lands in a committed file (GitHub push protection would flag it).
- **Hook-clean repo**: every committed file needs final newline, no trailing whitespace, no
  CRLF — or the required `pre-commit` check turns red.
- **Settings hot-reload**: the watcher picks up `~/.claude/settings.json` changes mid-session
  (proved by sentinel); registered hooks apply to the agent's own subsequent commands.
- **Branch checkouts rewrite the working tree**: symlinked skills/hooks vanish while a branch
  without them is checked out (fail-closed gitleaks guard then errors non-blockingly on
  missing script).
- **Permission denials observed**: compound Bash commands containing `rm`/`mv` get denied by
  the user's deny rules (split commands or avoid those binaries); the auto-mode classifier
  blocks ruleset toggles that bypass required checks (stop and hand the toggle to the user).
- **Claude Code cask exists** (`brew install --cask claude-code`) — verified before
  documenting.
- **IDE Mermaid**: `radar-beta` needs Mermaid ≥ 11.6 (IDE preview flags it; GitHub renders).

## 7. Pending / TODO (user decisions)

1. Add the required status check **`pre-commit`** to ruleset `main` (workflow ready, green).
2. Optional: rewrite `4bf307b` to 2026-07-08 23:07:24 +0200 (user toggles ruleset, agent
   force-pushes the rewritten tip).
3. Delete or keep the three leftover merged branches (local + remote).
4. Fix `create-review-about-codebase` frontmatter name mismatch
   (`create-review-report-about-codebase` vs directory name).
5. Fill or drop the duplicated "Codebase quality KPIs" section in
   `skills/ask-questions-about-codebase/SKILL.md` (repeats the Question Format block verbatim).
6. Remove or populate the empty `skills/create-pr/` directory.
7. End-to-end test of `/neo-challenge-review` (analyze → run → benchmark, resume behavior,
   clean `git status` in the submission) — still TODO from the previous session.
8. Decide the fate of this `HANDOVER.md` (keep untracked, gitignore, or publish via PR).
