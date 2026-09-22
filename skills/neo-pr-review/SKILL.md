---
name: neo-pr-review
description: >-
  deliver an evidence-based, blameless review of an open pull request on the
  currently checked-out branch; invoke only when the user explicitly runs
  /neo-pr-review. built for python cli data-pipeline projects spanning
  geospatial computing, terraform iac, kubernetes, ci/cd, databases, and
  airflow orchestration, where prs are usually opened by colleagues. first
  gather pr context: fetch its title, description, and author; when no author
  is assigned, attribute the pr to the top committer and offer to set that
  assignee; read the commit messages and their attached comments. review only
  the diff between the pr branch and the main branch and ignore untracked
  files. report correctness, recovery, security, operability, contract,
  testing, and unnecessary-complexity findings, and coach the author with
  actionable examples — documentation links and excerpts, code snippets,
  concrete improvements, and brief design-pattern explanations — suggesting
  the smallest coherent safe fix without implementing the changes.
disable-model-invocation: true
---

# Neo PR Review

## Goal

Deliver a critical, blameless review of a colleague's open pull request, judging the changed
behavior against its stated intent and recommending the smallest coherent safe production change.

Base the review strictly on the diff between the pull request branch and the target branch
(generally `main`). Everything outside that diff — untracked files and unrelated working-tree
changes — is out of scope and must be ignored.

Be strict about unnecessary complexity and stricter about correctness, recoverability, security,
and production diagnosis. Do not implement changes during review unless the user explicitly changes
the task to implementation.

## Getting started

Assume the user is already checked out on the branch under review and that it has an open pull
request, targeting the target branch (generally `main`), that is mergeable.

### Preflight checks

Validate these preconditions first, detecting the branches automatically from the repository and the
pull request. If any check fails, stop immediately, tell the user exactly what is wrong, and guide
them to fix it before re-running the skill — do not review anything. Do not infer or take corrective
actions yourself: only report the problem and the steps to fix it; the user resolves it and re-runs
the skill.

Read the pull request fields in a single call, for example
`gh pr view --json number,state,isDraft,baseRefName,mergeable,mergeStateStatus`.

- **Detect the default branch.** Read it from the repository settings via the API, never assume
  `main` — `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
- **Refuse the default branch.** Read the current branch (`git branch --show-current`); if it equals
  the default branch, stop and tell the user this skill requires already being on a feature branch
  that has an open, mergeable pull request to review.
- **Require an open pull request.** Confirm the current branch has an open pull request; if there is
  none, or it is closed or merged, stop and guide the user to open one, or to check out the correct
  branch. A draft pull request is fine to review.
- **Detect the target branch.** Take the base branch from the pull request itself, not from an
  assumption — `BASE="$(gh pr view --json baseRefName --jq .baseRefName)"` — and use it as the
  comparison base everywhere below.
- **Require a mergeable pull request.** Verify `mergeable`/`mergeStateStatus`; if the pull request
  is not mergeable (conflicts, out-of-date base, unknown state), stop and guide the user to resolve
  it — typically rebase onto or merge the target branch and fix conflicts — then re-run the skill. Do
  not try to solve or fix the conflicts yourself. A `DRAFT` merge state is acceptable.

### Build the pull request context

Once every precondition holds, gather the context from the pull request before reading any code.

1. **Fetch the pull request metadata and review status.** Read its title, description, author,
   assignees, requested reviewers, and commits, and its review status — whether it has one or more
   approvals, has blockers (requested changes, failing or pending required checks), or nothing yet.
   Get the metadata with `gh pr view --json title,body,author,assignees,reviewRequests,commits` and
   the status with `gh pr view --json reviewDecision,latestReviews,statusCheckRollup`.
2. **Read the history and discussion.** Go through the commit messages, the comments attached to
   the commits, and the existing review threads to reconstruct the intent and the sequence of
   decisions (`git log "$BASE"..HEAD`, `gh pr view --comments`). For each review thread, check
   whether it is resolved or still open (`reviewThreads.isResolved` via the GraphQL API); treat
   unresolved threads as open questions the review must still account for.
3. **Resolve the author.** Address the review to the pull request's author or assignee. If it has
   none, attribute it to the contributor with the most commits on the branch
   (`git shortlog -sn "$BASE"..HEAD`) and offer to set that person as the assignee
   (`gh pr edit --add-assignee <login>`); do not change it without confirmation.
4. **Add the current user as reviewer.** Register the requesting user as a reviewer on the pull
   request — `gh pr edit --add-reviewer "$(gh api user --jq .login)"`.
5. **Scope the diff.** Take the review surface as the diff between the pull request branch and the
   target branch (`gh pr diff` or `git diff "$BASE"...HEAD`). Only files in that diff are in scope;
   ignore every other file in the working tree.

## Instruction priority

Use this order when instructions compete:

1. Evaluate the user's stated requirement and acceptance criteria.
2. Preserve repository contracts and established conventions.
3. Identify credible correctness, security, recovery, and operability risks.
4. Apply YAGNI, KISS, and the implementation ladder.
5. Avoid style preferences that do not affect the change.

Do not request a larger design merely because it is more general or familiar.

## Shared engineering policy

Read [references/core-principles.md](references/core-principles.md) for every task. Then read only
the stack references relevant to the current boundary:

- [references/python.md](references/python.md)
- [references/airflow.md](references/airflow.md)
- [references/scientific-geospatial.md](references/scientific-geospatial.md)
- [references/terraform.md](references/terraform.md)
- [references/kubernetes.md](references/kubernetes.md)
- [references/ci-cd.md](references/ci-cd.md)
- [references/databases-migrations.md](references/databases-migrations.md)
- [references/data-pipelines-contracts.md](references/data-pipelines-contracts.md)
- [references/observability-recovery.md](references/observability-recovery.md)
- [references/security.md](references/security.md)

Treat these files as the canonical engineering policy. Apply them according to this skill's task boundary.

## Workflow

### 1. Establish the review boundary

Identify:

- the change set and comparison base
- the intended behavior
- the affected runtime, data, infrastructure, or release boundary
- the verification already present
- explicit exclusions

Infer these from the diff, branch, issue, tests, and surrounding code. Ask only when no meaningful
comparison or requirement can be established.

### 2. Inspect changed code and necessary context

Read the full changed files plus enough callers, tests, schemas, configuration, and deployment
context to understand the behavior. Do not review only isolated diff hunks when surrounding state
changes the conclusion.

Do not turn the review into a broad repository audit. Mention a pre-existing issue only when the
change introduces, worsens, depends on, or exposes it.

### 3. Apply the minimal-engineering ladder

For each material part of the change, ask whether it can safely:

1. **Remove or simplify**: delete code, remove duplication, or use existing configuration.
2. **Reuse project code**: use an existing function, component, resource, workflow, or convention.
3. **Use a native capability**: use a standard-library or first-party platform feature already available.
4. **Use an approved dependency**: use an existing project dependency instead of adding another concept.
5. **Use minimum new code**: retain only the custom behavior needed now.

Recommend an earlier rung only when it completely satisfies the requirement without hiding behavior or weakening safety.

### 4. Evaluate risk

Prioritize:

- incorrect or incompatible behavior
- data corruption, loss, duplication, or silent omission
- unsafe retries, partial failures, cancellation, or concurrent execution
- security, secret, permission, and trust-boundary failures
- destructive or surprising infrastructure changes
- missing operational evidence or recovery paths
- unnecessary complexity that increases the above risks

Apply the shared engineering policy for every active stack.

### 5. Verify findings

Use repository evidence and, when practical, non-destructive commands such as focused tests, type
checks, linters, DAG imports, schema validation, Terraform validation or plans, and manifest
rendering.

Never claim a command passed unless it was run and observed. Mark an unverified but credible issue
as conditional and state what would confirm it.

### 6. Report only actionable findings

A finding must include:

- a concrete location
- evidence from the changed behavior or its required context
- a plausible execution path or maintenance cost
- why it matters
- the smallest coherent safe fix
- a verification method

Combine duplicate symptoms under one root cause. Do not report hypothetical extensibility concerns,
personal style preferences, or generic best practices without a current impact.

## Decision and finding levels

Use one overall decision:

- **approve**: no material issue found in the inspected scope
- **simplify**: behavior is safe, with only non-blocking complexity reductions
- **request changes**: at least one required correctness, contract, test, clarity, or
  maintainability fix should be addressed before merge
- **block**: a credible path exists to data corruption or loss, leaked secrets, unsafe
  infrastructure mutation, outage, unrecoverable deployment, or an opaque production failure that
  makes release unsafe

Label each finding with one level:

- **block**: release or merge is unsafe until fixed
- **request changes**: required before merge, but not a release-blocking emergency
- **simplify**: optional non-blocking reduction in complexity

Do not inflate severity because a check is absent. Tie severity to the likely impact and the affected boundary.

## Evidence rules

- Cite `path:line` or the narrowest available location.
- Distinguish observed facts from inferences.
- State assumptions that materially affect a finding.
- Do not invent test results, runtime behavior, repository conventions, or production evidence.
- Do not require tests mechanically. Require the smallest test or verification that protects the changed behavior.
- Do not block on unrelated pre-existing debt.
- Do not suggest a rewrite when a local fix is sufficient.
- Do not implement or edit files unless the user explicitly requests it.

## Output

Start with findings, ordered by severity and impact. Omit empty sections.

```text
Neo review: approve | simplify | request changes | block
Scope: <change set and comparison base>
Why: <one or two sentences>

Findings:
1. [block | request changes | simplify] <title>
   Location: <path:line>
   Evidence: <observed behavior>
   Impact: <failure mode or maintenance cost>
   Smallest fix: <local coherent change>
   Verification: <specific test or check>

Keep: <correct or valuable parts worth preserving>
Deliberately not requested: <larger or speculative work avoided>
Verification performed: <commands and observed results, or not run with reason>
Residual risk: <limitations of the inspected scope>
```

When there are no findings, say so directly and still report the inspected scope, verification, and
residual risk. Do not manufacture praise or fill a stack matrix with `not applicable` entries.

## Completion criteria

Finish when:

- the review scope and intended behavior are clear enough to judge
- every reported finding is evidenced, actionable, and correctly scoped
- severity reflects impact rather than preference
- the smallest safe fix is identified without implementing it
- verification and uninspected risk are stated honestly
