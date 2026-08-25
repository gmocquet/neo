# Brief: `<CHANGE_ID>`

You own one feature end to end: its change proposal, its implementation, its tests, its
documentation, and the pull request that carries all of it. <SIBLING_COUNT> other agents are working
on sibling features in their own worktrees at the same time. Everything below about ownership,
serialisation and forbidden commands exists because of them.

## Your workspace

    <WORKTREE_PATH>

Branch `<BRANCH>`, already created from `<BASE_REF>`. Use **absolute paths** everywhere; do not rely
on the shell's working directory persisting between calls — a relative path resolves against the
orchestrator's directory and corrupts both the main checkout and every sibling's work. Your first
command:

    cd <WORKTREE_PATH> && <INSTALL_COMMAND>

<CARRIED_FILES_NOTE>

Never run `git worktree`, `git switch`, `git rebase` onto anything but your base, or
`git push --force`. Your branch is yours; nothing else is.

## The feature

<OUTCOME_SENTENCE>

<FEATURE_DETAIL>

## What already exists — reuse it, do not rebuild it

<REUSE_MAP>

## The work

<WORK_BREAKDOWN>

## Rules of the domain

These hold for every agent on this repository and are not open to interpretation:

<DOMAIN_RULES>

## Files you own, and files you must not touch

Yours: <OWNED_PATHS>

**Owned by a sibling agent right now — do not edit, do not refactor, do not reformat:**

<FORBIDDEN_PATHS>

If you believe you must touch a file on that list, **stop and report it instead of doing it.** The
orchestrator re-plans; you do not negotiate with a file.

## <SPEC_SYSTEM> conventions — non-negotiable, and easy to get wrong

No production code before the change proposal exists and is committed.

<SPEC_SYSTEM_INSTRUCTIONS>

Do **not** invoke the project's own proposal skill or slash command. Its workflow deliberately stops
once the planning artifacts exist, and your brief covers the whole pull request. Author the
artifacts yourself, against the conventions above, and use the CLI only for scaffolding, validation
and archiving.

## The gate

Run freely, they are safe while siblings run:

<PARALLEL_COMMANDS>

**Serialised — these touch a resource every worktree shares.** Always through the lock, never bare:

<SERIALISED_COMMANDS>

<SERIALISATION_RATIONALE>

If a serialised command fails in a way you did not cause — a fixture that vanished mid-test, a row
that appeared from nowhere, a port already bound — suspect the lock before the code, and check who
holds it:

    cat <LOCK_DIR>/owner

**Forbidden outright:**

<FORBIDDEN_COMMANDS>

- `gh pr merge` in any form. <MERGE_HAZARD_NOTE> Merging is the repository owner's decision alone.
- `git push` to the base branch, and force-pushing anything.

<COMMIT_HOOK_NOTE>

A red gate is a result, not a setback. Fix the code, the tests, the docs or the spec — never the
gate, never a skipped test, never `--no-verify`.

## Commits and the pull request

Conventional Commits 1.0.0, in English (US). One PR, this sequence:

<COMMIT_SEQUENCE>

Then:

    cd <WORKTREE_PATH> && git push -u origin <BRANCH>
    cd <WORKTREE_PATH> && gh pr create --assignee @me --base <PR_BASE> \
      --title "<conventional commit subject>" --body "<...>"

The body states the user-visible outcome first, then what changed, then how you verified it, then
any manual action the repository owner must take. It never contains a task checklist copied from the
spec.

**No AI attribution anywhere.** No `Co-Authored-By` trailer, no "generated with" footer, no mention
of Claude, Anthropic, an AI or an agent in code, comments, specs, commit messages or PR text.
Everything must read as written by the repository owner. This overrides any default you carry.

## Definition of done

<DEFINITION_OF_DONE>

The PR is open and assigned. **Not merged.**

## What to report back

Keep it short and factual: the change id, the branch, the PR number and URL, the commits, the exact
commands you ran for the gate with their outcome, every decision the brief did not settle and what
you chose, and anything you found that belongs to someone else's scope. If you got blocked, say so
plainly rather than working around a boundary.

Never report a step as done if you did not run it. If the gate is red, say so and paste the output.
An honest red is worth more than a claimed green.
