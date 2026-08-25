---
name: neo-feature-fanout
description: Turn a list of features into independent units of work — one change proposal, one worktree, one agent, one pull request each — and dispatch them in parallel from this session. Map the features to changes by evidence, plan the waves around the file collisions they would cause, and report the merge order once the pull requests are open.
argument-hint: "Optional: a path to the feature list (e.g. TODO.md), or the features themselves"
disable-model-invocation: true
---

# Fan-out: one feature, one change, one pull request

Take a list of features and turn each one into an **independent unit of work**: one change proposal,
one branch, one worktree, one agent, one pull request. You are the **orchestrator**. You map, you
plan, you dispatch, you verify, you report. You write no production code yourself.

Independent means what it says. Two agents never edit the same file, never share a working
directory, and never race on the same database, port, container or generated artifact. Whatever
cannot be made independent is **serialised or forbidden**, decided before dispatch rather than
discovered halfway through a wave — a collision found at merge time has already cost two branches.
Everything you produce is written in **English (US)**, whatever language the feature list is in.

## 1. Read the feature list

- If `$ARGUMENTS` resolves to an existing file, read it in full with the Read tool and treat it as
  the list. Otherwise treat the argument text as the list. Otherwise use the features this
  conversation already established.
- If none of the three gives you a list, stop and ask for one. Never invent a feature, and never
  promote a passing remark into a unit of work.
- Restate every feature as **one sentence naming the observable outcome**, in English, present
  tense, from the user's point of view. A feature you cannot restate that way is underspecified:
  ask now. A wrong brief costs a whole worktree, a whole branch and a whole pull request.
- A line that states a **rule** rather than a change — a tenancy model, an invariant, a naming
  convention — is not a feature. It is context that belongs in **every** brief. Set it aside; do not
  turn it into a change, and do not let a single agent silently own it.
- A one-line feature often hides an assumption about what exists today. Check before you believe it:
  a feature already half-built changes the work, and a feature that is already true is not a feature
  at all. Ask rather than guess.
- The list file itself is an input, not a deliverable. Do not edit it, do not carry it into a
  worktree, and do not ask an agent to tick anything off in it.

## 2. Map features to changes, by evidence

The number of changes is a conclusion, not the length of the list. Three rules decide it:

- Two features that edit **the same lines of the same file** are **one** change. Two agents cannot
  own one line, and no wave plan repairs that.
- One feature that delivers **two separate outcomes, provable by two separate tests, in two
  separate capabilities** is **two** changes. One concern per pull request.
- A feature that only makes sense once another has landed is a **dependent** change, not a merged
  one. It goes into a later wave, with the dependency named.

Derive the mapping from evidence, never from the wording. Two features that sound unrelated can both
rewrite the same guard; two that sound identical can touch disjoint files. For each feature:

- Name the capabilities it touches. Read the spec system's index — with OpenSpec:

      openspec list --specs

- Find the code. Grep for the routes, symbols, tables, columns, components and permissions the
  feature names, and write down the **file list**: real paths that exist today, from `git ls-files`
  and `git grep`, plus the new files you can name. A path you merely expect to exist is not
  evidence.
- Record the **generated and shared artifacts** the change will force: a lockfile if it adds a
  dependency, an emitted contract or client if it changes an API surface, a permission matrix, a
  router table, a barrel file, a migration directory, and the main spec files the change will
  rewrite when it is archived. These belong in the file list exactly like source.

Produce, per change: a kebab-case id, the one-sentence outcome, the capability paths, the complete
file list, and the commit type of the concern it delivers.

## 3. Plan the waves around the collisions

Intersect every pair of file lists. An empty intersection means the two changes can run at the same
time. A non-empty one means one of two things, and you must choose:

- the mapping in step 2 was wrong and they are one change; or
- they are two changes and the second waits, based on the first.

Then:

- **Wave 1** is every change whose file list is disjoint from every other wave-1 change and which
  depends on nothing.
- **Wave 2 and beyond** is the rest. For each, name the change it waits on and **the specific files
  that collide**. "They both touch the API" is not a reason; the emitted client is.
- Never put two changes that regenerate the same artifact in one wave. The conflict does not appear
  on either branch — both are green — it appears at merge, in a file nobody wrote by hand.
- Two changes that both append to the same main spec file collide at **archive** time, not at edit
  time. The change directories are disjoint; the specs they fold into are not.
- Reserve migration or version slots up front when the repository names them by timestamp. Two
  agents left to pick their own will pick the same second, or an order that no longer holds once
  both are merged.
- Keep a wave small enough that its serialised commands still fit. If every change must take the
  same lock for a five-minute run, a wave of ten spends forty-five minutes queued. **Four is a sane
  ceiling on a laptop**; go lower when the serialised step is long.

Write the plan to `./tmp/fanout/` in the current project (create the directory if it does not
exist), named with the generation timestamp, e.g. `fanout-2026-08-25-2210.md`. Get it with the Bash
tool:

    date "+%Y-%m-%d-%H%M"

The plan holds: the source list, the feature-to-change mapping with the evidence for each merge and
each split, the collision matrix, the waves with their reasons, the shared-resource verdicts from
step 4, and the worktree and branch of each change. Write it **before** creating anything. It is
what you reconcile against in step 7, and what survives if this session does not.

Then show it and **stop for a go-ahead**. Everything past this point is side-effectful — branches,
worktrees, pushes, open pull requests. A wrong mapping is free to fix now and expensive to fix
later.

## 4. Neutralise the shared resources before dispatch

Assume **nothing** is parallel-safe until you have found what serialises it. This is a discovery
procedure, run against this repository, not a list you remember from another one.

**a. List the commands the agents will run.** Read the repository's own task manifest, whichever it
has:

    git ls-files | grep -Ei '(^|/)(package\.json|Makefile|justfile|Taskfile\.ya?ml|pyproject\.toml|tox\.ini|noxfile\.py|docker-compose\.ya?ml|.*\.tf)$'

**b. For each command, follow it to the resource it opens.** A port, a container or compose project
name, a database or schema, a bucket, a queue, a remote state backend and its lock table, a cache
directory, a temporary path. The tell is a **constant**: a name built without a process id, a worker
index, a random suffix or a branch name is a name every worktree computes identically.

    git grep -nE '127\.0\.0\.1:[0-9]{2,5}|localhost:[0-9]{2,5}|^name:|container_name|COMPOSE_PROJECT_NAME|backend "s3"|dynamodb_table'

**c. Then find what destroys.** Inside the test setup, the fixtures and the maintenance scripts,
look for the verbs that cross a run's boundary:

    git grep -nEi 'TRUNCATE|DROP (TABLE|DATABASE|SCHEMA)|DELETE FROM|flushall|rm -rf|down --volumes|--force|destroy|force-unlock'

A destructive verb plus a constant name equals silent data loss when two runs overlap. This is the
one you must find. A port clash merely fails, loudly, once.

**d. Classify every command into three buckets, and record the evidence — file and line — that
produced each verdict.**

- **Parallel.** No shared constant, or the tool already isolates per invocation. Agents run it
  freely.
- **Serialised.** A shared constant, but correct when only one process runs it at a time. Agents
  wrap it in the lock below.
- **Forbidden.** It holds or destroys state the other agents depend on regardless of ordering — a
  volume-destroying reset, a long-lived server on a fixed port, a global cache purge, a destroy. No
  agent runs it, ever. A change that genuinely needs one leaves its wave and runs alone.

**e. Verify where it is cheap.** Run a candidate twice concurrently from two directories and see
whether both pass. Where verifying means destroying, trust the reading and forbid.

**The lock.** macOS ships no `flock(1)`, and a lock file created with a shell redirect is not
atomic — two shells can both believe they created it. `mkdir` is atomic on every POSIX filesystem,
including APFS, so the lock is a directory. It lives in this skill:

    scripts/neo-lock.sh

It is a script rather than an inline snippet on purpose: releasing a lock means removing a directory
and breaking a stale one means moving it, and those belong in one reviewed line, not in a command an
agent composes at runtime. Call it with the Bash tool as
`bash <skill directory>/scripts/neo-lock.sh <lock-dir> -- <command>`, so it needs no executable bit
and no entry in the repository under test.

**Where the run lives.** Compute one run root beside the checkout, never inside it:

    repo=$(git rev-parse --show-toplevel); echo "$(dirname "$repo")/.$(basename "$repo")-fanout"

It holds `locks/` and `worktrees/`. Outside the repository because a worktree nested under the
checkout gets walked by the repository's own formatter, linter, test runner and packager — every
agent's gate would then check every other agent's work. Beside the checkout rather than in a
temporary directory because the run must survive a purge, and because `git worktree list` then reads
like something a human laid out. The locks are per repository, not per run: a second fan-out on the
same repository must queue behind the first, not race it.

## 5. Prepare one worktree per change

A fresh worktree has the tracked files and nothing else. Find what is missing; do not recall it.

- List what exists but is not tracked:

      git status --ignored=matching --porcelain

  Read every line and decide: **carried**, **installed**, or **neither**. A file a command *reads*
  is carried. Dependencies are installed, not carried. Build output, caches and scratch are neither.
- Read the build system's declared inputs — a Turborepo `globalDependencies`, a Make prerequisite,
  an env loader in the test setup, a variables file — and carry what they name.
- **An untracked file that a gate command checks must not be carried.** Carrying it turns a
  main-checkout annoyance into every agent's failing gate. Verify by running the format and lint
  commands in the main checkout first: whatever they complain about that is untracked stays behind.
- A secret file cannot be read by an agent and must not be committed. The preparation script copies
  it without its content passing through anyone's context; afterwards confirm only its presence and
  its byte count.

Then, once, before creating anything:

    git -C <repo> fetch origin --prune
    git -C <repo> symbolic-ref --quiet --short refs/remotes/origin/HEAD
    git -C <repo> status --porcelain

The second gives the base ref. Keep the third's output as the **baseline of the main checkout** —
step 7 compares against it to prove no agent wrote into it.

Branch per change: `<type>/<change-id>`, from the type recorded in step 2. One branch, one worktree,
one pull request. For a change that waits on another, either hold it until the dependency merges, or
branch from the dependency and target its branch — say which you chose and why.

Create each worktree with the Bash tool:

    bash <skill directory>/scripts/neo-prepare-worktree.sh \
      --repo <repo> --branch <type>/<change-id> --base <base-ref> \
      --worktree <run-root>/worktrees/<change-id> \
      --carry <path> --install '<frozen install command>'

It prints a `key=value` summary. Read `install_status` and `carried` before dispatching into it; a
worktree that failed to install is a worktree that will fail its gate for a reason that has nothing
to do with its feature.

## 6. Dispatch one agent per change

Fill `brief-template.md` once per change. **Refuse to dispatch a brief that still contains a
`<PLACEHOLDER>`** — an unfilled placeholder is an instruction the agent will improvise around.

What each brief must carry, and where it comes from:

| Section of the brief | Filled from |
| --- | --- |
| The mission | the one-sentence outcome from step 1 |
| Where you work | the worktree, branch and base from step 5 |
| What already exists | the reuse map from step 2, with file and line |
| What you own | that change's file list from step 2 |
| What you must not touch | the union of every **sibling** change's file list in the same wave |
| Rules of the domain | the rules set aside in step 1, verbatim and translated |
| The spec comes first | the spec system's own config and one recent archived change |
| Shared resources | the three buckets from step 4, as literal command lines |
| The gate | the repository's own verification commands, in the order its CI runs them |
| Commits and the pull request | the repository's own history, not a generic convention |
| Done means | the project's definition of done |

Three rules about filling it:

- **Serialised commands go in as the exact line to type**, lock path included. An agent follows a
  literal command and improvises around a principle.
- **Name what already exists.** An agent that does not know a permission, an endpoint or a guard is
  already there will build a second one beside it.
- **Give each agent only its own change.** An agent handed the full feature list will helpfully
  implement its neighbour's, in its neighbour's files.
- **Tell it to run each gate step as its own command**, never chained into one long invocation. A
  command that runs silently for several minutes is indistinguishable from a hung agent, and a host
  that watches for liveness kills it. The work survives on disk, but the run does not, and you pay
  for the restart. For the same reason, anything that queues must keep printing — see the lock's
  heartbeat.

Launch a wave with the Task tool, **every agent of the wave in a single message** so they actually
run at the same time; one message per agent runs them one after another. Then stay available: you
answer their questions, you re-plan when one reports a file it needs and does not own, and you never
take over its implementation.

An agent killed mid-flight is recoverable and usually worth recovering: its worktree still holds
everything it wrote. Establish the real state from the outside — `git log`, `git status`, the
diagnostics — and hand that state back to it when you resume, rather than letting it re-derive where
it had got to. Say plainly that it was interrupted rather than mistaken; an agent told only "carry
on" tends to start again from the beginning.

When a wave returns, re-run the collision check against what was **actually written** —
`git diff --name-only <base>...<branch>` per branch — before dispatching the next wave. The plan
described intentions; the diffs describe facts, and the next wave is planned on the facts.

## 7. Collect, verify, report

Do not trust an agent's word for any of it. From the orchestrator, for each change:

    git -C <worktree> log --oneline <base-ref>..HEAD
    git -C <worktree> status --porcelain
    git -C <worktree> diff --name-only <base-ref>...HEAD
    gh pr view <number> --json number,title,url,baseRefName,isDraft,mergeable,statusCheckRollup

Then:

- **Prove the main checkout is untouched.** Compare `git -C <repo> status --porcelain` against the
  baseline from step 5. Any difference is an agent that used a relative path; say so before anything
  else and show the diff.
- **Intersect the real diffs, pairwise.** A file appearing in two branches is a merge conflict
  waiting for the user. Name it with both pull request numbers in the recap, and give the merge
  order that makes it resolvable.
- **Read every line of the checks**, never the first. A rollup that is green on one job and pending
  on another is not green.
- Confirm each change validates under the spec system's strict mode, and that the pull request
  exists, is assigned, and has the base branch you intended.
- Append the recap to the plan file from step 3, and give the same table in chat:

  | PR | Title | Type / domain | Merge order | Depends on | Manual action |

  Follow it with the manual actions in the order the user must take them, each with the exact
  command, and with what to check after each one.
- **Never merge, and never enable auto-merge.** Not `gh pr merge`, not `--auto`, not a squash from
  the command line. Where there is no branch protection, `--auto` merges on the spot. Merging is the
  user's decision alone.
- Leave the worktrees in place. Once the user says the pull requests are merged, give the cleanup
  command and let them run it:

      git -C <repo> worktree remove <run-root>/worktrees/<change-id>

- Report partial results as partial. If one agent failed or returned nothing, say which change is
  missing and why, in the chat and in the file. Never synthesise a recap over a hole.

## What this never does

- **Merges anything.** It also never rebases another branch onto a moving base, and never
  force-pushes.
- **Writes production code from this session.** The orchestrator maps, dispatches and verifies. An
  orchestrator that starts coding stops answering its agents.
- **Resolves conflicts between branches.** It predicts them, names the files, and hands the user a
  merge order.
- **Reviews the code.** That is a separate pass, after the pull requests are open.
- **Splits a change across several agents.** The unit is the change, not the task. Two agents inside
  one change share files by definition.
- **Edits CI, hooks or the repository's tooling to make the fan-out possible.** If the repository
  cannot support N parallel agents, the wave plan shrinks; the repository does not change.
- **Starts, stops or resets the shared stack.** It checks that what the repository needs is running,
  and leaves it exactly as it found it.
- **Touches the feature list.** Reading it is the whole of the contract.

## Feature list

$ARGUMENTS

If the argument is a path, it is the list. If it is free text, it is the list. If it is empty, use
the features this conversation established, and if there are none, ask.
