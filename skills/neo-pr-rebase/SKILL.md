---
name: neo-pr-rebase
description: >-
  rebase the currently checked-out feature branch onto the freshest remote
  target branch, resolve every conflict on your own, run the project's local
  test suite, and force-push the result with --force-with-lease; invoke only
  when the user explicitly runs /neo-pr-rebase. built for python cli
  data-pipeline projects (uv, pytest, ruff, make targets) but works on any git
  repository with a local test command. the user expects autonomy: ask them
  only when a conflict is truly undecidable from the code, its history, and
  its tests, never for routine conflicts, and never push a branch whose tests
  fail. every repair beyond the conflict itself lands in a dedicated,
  revertible commit so the original pull-request commits stay as their author
  wrote them.
disable-model-invocation: true
---

# Neo PR Rebase

## Goal

Bring the current feature branch up to date with its target branch through a rebase, with every
conflict resolved, the local tests green, and the result pushed with `--force-with-lease`. The
user is not in the loop unless a conflict cannot be settled from the repository itself.

## Boundaries

- Never rebase the default branch, and never rebase a branch that is not the checked-out one.
- Never drop history that someone else pushed since the local branch was last synced: if the
  remote branch moved, integrate those commits first (see "Remote drift").
- Never use `--force` without `--force-with-lease`, never `git push` while tests fail, and never
  `git rebase --skip` to get past a conflict.
- Never `git stash drop`, `git reset --hard`, `git checkout -- .` or any other command that
  discards uncommitted work. Uncommitted changes are stashed before the rebase and restored after.
- Never continue on a stale remote: if `git fetch` fails, stop and report the error.
- Never modify an original commit beyond what its conflict forces: the resolved hunks and their
  lint fix stay in the replayed commit, every other repair goes to a dedicated commit (see
  "Repair commits").
- Ask the user only in the situations listed under "When to ask". Everything else is decided here.

## Workflow

### 1. Establish the state

```bash
git status --porcelain
git branch --show-current
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
gh pr view --json number,baseRefName,headRefName,url 2>/dev/null
git fetch --prune origin
git rev-parse @{upstream} 2>/dev/null
```

- `git fetch` must succeed; an authentication or network error stops the run with the message
  reported as is, since everything after it would rely on a stale remote.
- Git must never open an editor: this environment cannot drive one and `git rebase -i` is not
  available. Prefix every `git rebase`, `git rebase --continue` and `git commit` with
  `GIT_EDITOR=true` (or export it once), and never pass `-i`.
- The target branch is the PR base when a PR exists, else the repository default branch.
- Record the current head (`git rev-parse HEAD`) as the recovery point and name it in the final
  report.
- If the working tree is dirty, `git stash push --include-untracked -m "neo-pr-rebase <date>"`
  and restore it with `git stash pop` after the rebase. Report it either way.

### 2. Remote drift

Compare the local branch with its upstream before touching anything:

```bash
git rev-list --left-right --count @{upstream}...HEAD
git log --oneline HEAD..@{upstream}
```

When the upstream holds commits the local branch lacks (a colleague pushed, or the user worked
from another machine), bring them in before the rebase so that nothing gets lost:

```bash
git rebase @{upstream}
```

This replays the local-only commits on top of the remote ones; the remote commits stay first and
untouched. Conflicts here are resolved exactly like the ones of step 4, with the remote side as
"ours". When the same commits exist on both sides with different hashes (a previous rebase was
pushed from elsewhere), `git rebase` drops the duplicates by patch identity; check the result
with `git log --oneline @{upstream}..HEAD` and make sure only the genuinely local commits remain.

Report the integrated commits (count and one-line summary) in the final report. After this step
the local branch contains everything the remote had, so the later `--force-with-lease` push only
replaces history this run rewrote.

### 3. Rebase

```bash
git rebase origin/<target>
```

If the branch is a stack (its PR base is another feature branch), rebase onto `origin/<base>`,
not onto the default branch.

Read the target's recent history first (`git log --oneline HEAD..origin/<target>`) to know what
landed: it is the context for every conflict.

### 4. Resolve conflicts

Handle each stop of the rebase in turn:

```bash
git status --porcelain            # UU / AA / DU / UD entries
git diff --name-only --diff-filter=U
git log -1 --format='%h %s' REBASE_HEAD   # the commit being replayed
```

For each conflicting file:

1. Read the whole file with its markers, and both sides in context:
   `git show :2:<path>` (target side, "ours" during a rebase) and `git show :3:<path>` (the
   commit being replayed, "theirs"). Read the target-branch commits that touched the file
   (`git log --oneline origin/<target> -- <path>`) and the replayed commit's message.
2. Decide from intent, not from position: keep what the target branch changed, apply on top of it
   what the replayed commit meant to do. When both sides changed the same lines, the result must
   satisfy both intents; when one side deleted what the other edited, follow the deletion only if
   the edit is meaningless without it.
3. Typical shapes and their resolution:
   - **Imports, `__all__`, constant blocks, Makefile `.PHONY`, registration lists**: keep both
     sides, in the file's existing order.
   - **Migration chains, auto-numbered files, lockfiles**: git cannot merge these by text; follow
     "Semantic conflicts" below.
   - **Generated or formatted files**: take the target side and rerun the generator or formatter.
   - **Deleted upstream, edited here**: if the target removed a module the replayed commit edits,
     port the edit to wherever the target moved that code; if the code is gone for good, drop the
     edit and say so in the report.
   - **Renamed upstream**: apply the replayed edit to the renamed file.
4. Remove every marker, then run the project's formatter and linters on the resolved files only
   (`uv run ruff format <path> && uv run ruff check --fix <path>`, `npx prettier --write <path>`,
   `npx eslint --fix <path>`, `terraform fmt <path>`, or `uv run pre-commit run --files <path>`
   when the repository has hooks), plus the fastest correctness check (`python -c "import ..."`,
   `bash -n`). Whatever the tools rewrite belongs to the resolution: `git add` the files again,
   then `GIT_EDITOR=true git rebase --continue`.
5. When `rebase --continue` is refused by a pre-commit hook that rewrote files, the resolution is
   not done yet: `git add` the rewritten files and run `--continue` again until the hook passes.
   The replayed commit is created only once, with the resolution and its lint fix together, so
   every commit of the branch stays lint-clean. A hook failing on something the resolution did not
   touch and already failing on the target is bypassed for that commit with `--no-verify` and
   named in the report; the gates of step 5 run the hooks on the whole branch afterwards.
6. Do not amend the replayed commit's message unless the conflict changed its scope.

Keep a running list of every resolution: file, commit, what each side wanted, what was kept. It
goes in the final report.

### 4b. Semantic conflicts

Some conflicts are not about text. Git either reports a conflict it cannot express (two files
that both claim to be "next"), or reports none at all while the result is broken (two migrations
that both descend from the same parent). The rebase only ends when these are settled too, so
check for them after every conflicting stop and once more when the rebase finishes, before the
gates. They are easy to settle from the code; never ask the user for them.

**Database migration chains.** Alembic (Python), Flyway (SQL), TypeORM, MikroORM, Sequelize,
Knex.js and Prisma (Node.js) all keep an ordered chain of revisions. When the target branch added
revisions, the replayed revision still points at the parent it had when it was written, so the
chain forks or two files claim the same number.

- Find the target's newest revision: the file with the highest number or timestamp under the
  migrations directory, the `revision`/`down_revision` pair for Alembic, the version in the file
  name for Flyway (`V<version>__<name>.sql`), the timestamp prefix and the `migrations` table entry
  for the Node.js tools, the folder name under `prisma/migrations` for Prisma.
- Re-attach the replayed revision to that head: Alembic `down_revision = "<target head>"` and a
  fresh `revision` id when the old one collides; Flyway and the Node.js tools: rename the file to
  the next free number or a timestamp later than the target head; Prisma: rename the migration
  folder to a later timestamp. Do it after the rebase finished, in one dedicated commit
  `chore(rebase): re-attach migration <old> as <new>` (see "Repair commits"), not inside the
  original commit that introduced the migration.
- Renumbering renames the file, so update every reference to its old name or id in the same
  repair commit: READMEs, local scripts that assert a revision, tests that list the migration
  chain, `alembic_version` checks.
- Prove the chain is linear with the tool itself: `uv run alembic heads` must print one head,
  `uv run alembic history -r <target head>:` must end on the replayed revision; Flyway
  `flyway validate`; the Node.js tools with their `migration:show` or `status` command against
  the local database when one is available. The repository's migration test (for example a
  `test_baseline_chain.py`) runs in the gates and is the last word.
- Never edit the target's migrations to make room; the number the target took is theirs.

**Auto-numbered files.** Any prefix-numbered sequence (`0051_…`, `001-…`, ADR or AgDR ids,
`V12__`, numbered fixtures) has the same failure: the target consumed the number the replayed
file expected. Rename the replayed file to the next free number after the target's highest one
and update every reference to the old name (indexes, tables of contents, cross-links, tests that
enumerate the directory), in one dedicated commit `chore(rebase): renumber <old> to <new>`. When
two of the branch's own files are renumbered, keep their relative order.

**Dependencies and lockfiles.** When both sides changed dependencies, the manifest and the
lockfile diverge together. Never hand-merge a lockfile; merge the manifest, then regenerate.

1. Resolve the manifest by intent, keeping both sides: `pyproject.toml`, `package.json`,
   `versions.tf` / `required_providers` / module `source` and `version` pins. Two different pins
   of the same dependency: keep the newer version unless the replayed commit deliberately pinned
   an older one and says why.
2. During the rebase, take the target side of the lockfile as is (`git checkout --ours
   <lockfile>`) so the replayed commit can be created; the regeneration comes after the rebase,
   from the merged manifest, with the project tool: `uv lock` (then `uv sync` so the gates run on
   it), `npm install --package-lock-only` (or `pnpm install --lockfile-only`,
   `yarn install --mode update-lockfile`), `terraform init -upgrade` / `tofu init -upgrade` for
   `.terraform.lock.hcl` (add `-platform` flags when the repository pins several platforms).
3. Check that the regenerated lockfile only differs by the dependencies each side touched
   (`git diff --stat`, and `uv lock --check` / `npm ci --dry-run` when available); a lockfile that
   rewrote unrelated packages means the tool version differs from the one the repository uses,
   so match it before continuing.
4. Commit the regenerated lockfile alone as `chore(rebase): regenerate <lockfile>`, single line
   (see "Repair commits"). A lockfile git did not flag but that no longer matches the merged
   manifest (`uv lock --check` fails) gets the same treatment.

Every semantic resolution goes in the report with the old and new numbers, ids or versions.

### 4c. Repair commits

The rebase is meant to be automated: small problems it creates are fixed without asking. But the
original commits of the pull request stay as their author wrote them, apart from the hunks a
conflict forced and their lint fix. Every other change this run makes lands in its own commit,
after the rebase, so that the user can review it in the PR and drop it with `git revert` if they
disagree:

- one commit per repair, single-line conventional message with the `rebase` scope:
  `chore(rebase): regenerate uv.lock`, `chore(rebase): re-attach migration 0051 as 0052`,
  `fix(rebase): adapt import to the renamed helper`, `test(rebase): update the migration chain
  test`;
- a repair commit only contains what the repair needs; never fold two repairs into one, never
  slip a repair into an original commit with `--amend` or `rebase -i`;
- every repair commit is listed in the report with its hash and a one-line reason, and the
  report ends with the command that removes them all
  (`git revert --no-edit <hash>...` in reverse order).

`git log --oneline --grep='(rebase)' origin/<target>..HEAD` lists them at any time.

### 5. Verify

After the rebase, bring the checkout in line with the rebased tree, then restore the stash:

```bash
git submodule update --init --recursive      # when .gitmodules exists
git lfs checkout                              # when .gitattributes declares lfs filters
git stash pop                                 # when step 1 stashed something
git status --porcelain
git log --oneline origin/<target>..HEAD
```

If `git stash pop` fails or reports a conflict, leave everything as it is: do not resolve the
conflict, do not drop the stash, do not touch the files it marked. The user's uncommitted work
is not part of the rebase. Then, in the report:

1. Explain what went wrong: the exact output of `git stash pop`, the files in conflict
   (`git diff --name-only --diff-filter=U`), and why they conflict (which rebased commit changed
   the same lines as the stashed work; `git diff stash@{0}^ stash@{0} -- <path>` shows the
   stashed hunk, `git log --oneline -1 -- <path>` the commit that moved under it).
2. Guide the user back to a clean state with the commands to run, in order, on their machine,
   each with a one-line comment. Every command must be complete and ready to paste: real file
   paths, the real stash index, the real branch name and hashes of this run. No placeholder, no
   `<path>`, no "adapt as needed". When several files are involved, write one line per file. The
   shape, filled with this run's values, is:

   ```bash
   git status                                                  # files left in conflict by the stash pop
   git checkout -- src/hydrosat/hywater/cli/root.py            # drop the failed merge of this file; the stash still holds your version
   git stash show -p stash@{0}                                 # review what the stash holds before applying it again
   git stash apply stash@{0}                                   # re-apply it; the same file will show conflict markers
   # edit src/hydrosat/hywater/cli/root.py by hand: keep the rebased import block and your new option below it
   git add src/hydrosat/hywater/cli/root.py                    # mark the file as resolved
   git stash drop stash@{0}                                    # only once every file is as wanted
   ```

   Say plainly which step the user must check by eye and what to look for in the file. When a
   `git stash apply` would be refused because the tree is dirty, write the exact `git add` or
   `git stash push` line that clears the way first, with the paths it applies to.

Continue the gates on the committed tree only if the working tree is clean apart from the stash;
otherwise stop before the gates, do not push, and report.

Run the project's local gates, in this order, stopping at the first failure:

1. Format and lint: the repository's target (`make fix_linting_issues`, else
   `uv run ruff format . && uv run ruff check .`).
2. Full unit suite: the repository's target (`make run_unit_tests`, else `uv run pytest tests/unit`,
   else the command named in `AGENTS.md`, `CLAUDE.md`, `Makefile`, `package.json`).
3. Hooks on the branch diff: `uv run pre-commit run --from-ref origin/<target> --to-ref HEAD`
   when `.pre-commit-config.yaml` exists.

Type checks are run when the repository has a target for them (`make check_types`). A failure
that also exists on the target branch is reported, not fixed: compare against
`git worktree add /tmp/neo-rebase-base origin/<target>` and remove the worktree afterwards.

If a gate fails because of the rebase (a test broken by the meeting of two changes, an import
the target renamed, a formatter that rewrote a file), fix it in a repair commit (see "Repair
commits") and rerun the gates from the first one. If it fails for a reason unrelated to the
rebase and already present on the target, report it and continue. If it fails and the cause is
not clear, do not push; report.

### 6. Push

Only when every gate above passed:

```bash
git push --force-with-lease origin <branch>
```

If the push is rejected by the lease, someone pushed during the run: do not retry with a weaker
flag. Report the rejection and the remote commits.

### 7. Report

Say plainly, in this order:

- remote commits integrated before the rebase, if any (count and one-line summary);
- target branch and the commits the branch was rebased over (count and one-line summary);
- every conflict and how it was resolved, file by file, with the reasoning when it was not
  mechanical, semantic ones included (old and new revision ids, file numbers, versions);
- every repair commit, with its hash and reason, and the `git revert` command that removes them;
- gate results with the observed output (test counts, lint status), or `not run` with the reason;
- the push result, the new head, and the recovery point (`git reflog` or the pre-rebase hash) in
  case the user wants to undo.

## When to ask

Ask the user, with the exact conflicting hunks quoted, only when:

- both sides changed the same logic in ways that contradict each other and neither the commit
  messages, the PR descriptions, the tests, nor the surrounding code say which behavior is
  wanted;
- the target branch deleted a feature the current branch builds on and no replacement exists;
- resolving would require changing a public contract (schema, API, CLI option) beyond what the
  replayed commit did.

Before asking, say what was tried and what the two candidate resolutions would each break.
Everything else (import order, renamed helpers, migration chains, auto-numbered files, lockfiles,
formatting, overlapping docs edits, duplicated test helpers) is resolved without asking.

## Recovery

If a rebase must be abandoned, `git rebase --abort` returns to the state before that rebase (the
recovery point for the first one, the integrated branch for the second). If the
branch was already rewritten and the user wants the previous state back:
`git reset --keep <recovery-hash>` followed by `git push --force-with-lease origin <branch>`,
and say so in the report rather than doing it unprompted.

## Done when

- `git fetch` succeeded and the remote commits of the feature branch, if any, are part of the
  local branch;
- the branch sits on top of `origin/<target>` (`git merge-base --is-ancestor origin/<target> HEAD`)
  and no rebase is in progress (`.git/rebase-merge` and `.git/rebase-apply` are absent);
- the working tree is clean, the stash is restored or named in the report, submodules match;
- every conflict, textual or semantic, is resolved and listed in the report;
- format, lint, unit tests and hooks are green on the rebased branch, and type checks either
  pass or fail only on diagnostics the target branch already has;
- the push with `--force-with-lease` was accepted, or the report says why it was not attempted;
- the report names the recovery point, every repair commit and the command that reverts them.
