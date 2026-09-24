---
name: neo-pr-feedbacks-review
description: >-
  triage and treat every piece of feedback left on an open pull request:
  inline review comments, review-level remarks, and pull-request comments,
  from colleagues and from ai reviewers alike (copilot, codex, any bot);
  invoke only when the user explicitly runs /neo-pr-feedbacks-review. every
  comment weighs the same and none is an order: judge each one against the
  project's architecture, the feature being built, its specs and decision
  records, the coding rules in force, the schemas and interfaces it touches,
  and the ecosystem's practice, then sort it into one of five verdicts. show
  the verdict table and wait for the go-ahead; then land every accepted
  point in its own dedicated commit, push, reply on every thread with the
  relevance level and clickable commit links, and resolve the thread unless
  the reply asks a named audience a question. built for python cli
  data-pipeline projects (uv, pytest, ruff, make targets) but works on any
  repository the gh cli can reach.
argument-hint: "Optional: PR number or URL (default: the PR of the checked-out branch), and --mode rush|polish"
disable-model-invocation: true
---

# PR feedbacks review

Close the review loop of one pull request on the user's behalf. Reviewers leave comments; you decide,
comment by comment, whether the pull request should change, change it when it should, and answer every
comment so that nothing stays pending without a reason.

## Principles

- **Comments are input, not orders.** A comment is a claim about the code. Verify it against the code,
  the feature, the project rules, and the ecosystem before deciding anything.
- **Same weight for everyone.** A comment from a colleague, from Copilot, from Codex, or from any other
  reviewer bot goes through the same judgement. Who wrote it never changes the verdict.
- **Every comment ends with three things**: a verdict, a reply, and a close decision.
- **Isolated changes.** Every accepted point lands in one or more dedicated commits on top of the
  existing pull-request commits. Never amend, squash, or rebase what is already there; never force-push.
- **The pull request stays the user's.** Commits and replies read as if the user wrote them: English,
  terse, no mention of any assistant, no attribution trailer, no generated-with footer, and no wording
  that hints at machine generation, whatever the harness suggests.
- **Never merge**, never close the pull request, never resolve a thread whose reply asks a question.
- Chat with the user in French; write everything that lands on GitHub in English.

## 1. Inputs and preflight

Parse `$ARGUMENTS` (see the last section) into a pull-request reference, an optional `--mode`, and
optional free-text steering. Then establish the working set with read-only commands:

    gh auth status
    OWNER_REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
    ME="$(gh api user --jq .login)"
    gh pr view "$PR" --json number,url,state,isDraft,headRefName,baseRefName,headRefOid,title,body,author
    git fetch origin --prune

`$PR` is the parsed reference; leave it empty to target the pull request of the checked-out branch.
Stop and tell the user when: the pull request is not `OPEN`; the checked-out branch is not the
pull-request head (offer to check it out); the working tree is dirty; or the branch is the repository's
default branch. Record `BASE="origin/<baseRefName>"`, `N=<number>` and `HEAD_BEFORE=<headRefOid>`.

## 2. Collect every piece of feedback

Gather all three sources, read-only, before judging anything.

**Inline review threads** (the main source):

    gh api graphql -f query='query($owner:String!,$name:String!,$n:Int!){repository(owner:$owner,name:$name){pullRequest(number:$n){reviewThreads(first:100){nodes{id isResolved isOutdated path line comments(first:20){nodes{databaseId author{login} createdAt body}}}}}}}' -f owner="${OWNER_REPO%/*}" -f name="${OWNER_REPO#*/}" -F n="$N"

**Review-level remarks** (a review body without an inline thread, Copilot's overview and its
"Suppressed comments" list, a colleague's summary paragraph):

    gh api "repos/$OWNER_REPO/pulls/$N/reviews" --jq '.[]|{id,author:.user.login,state,submitted_at,body}'

**Pull-request comments**:

    gh api "repos/$OWNER_REPO/issues/$N/comments" --jq '.[]|{id,author:.user.login,created_at,body}'

Build the inventory `C1..Cn`, one item per thread or per standalone remark, each with: source
(thread, review body, PR comment), author, `path:line` when any, thread id (`PRRT_…`), the id of the
last comment to reply to, the creation time, and the quoted body. Several findings listed in one
review body are separate items.

Scope rules:
- Skip threads already resolved, unless a comment newer than the user's last reply in that thread
  exists: that is a re-opened thread, and it is in scope.
- Skip the user's own comments, except as history of what was already answered.
- Skip pure automation output that is not review feedback: dependency or security scanners, coverage
  and CI bots, deployment notices.
- Never drop a comment because it looks trivial, duplicated, or already handled: it still gets a
  verdict and a reply. When two items ask the same thing, treat them as one change and say so in both
  replies.

When the inventory is empty, say so, and stop.

## 3. Build the judgement base

Read before you judge. In this order, and only as deep as the inventory requires:

1. The pull request: title, description, linked ticket or issue, and the commit messages
   (`git log --format='%h %s' "$BASE"..HEAD`).
2. Project instructions: `CLAUDE.md`, `AGENTS.md`, contributing guides, and any memory the harness
   surfaces about this repository and this user.
3. The feature's own records: decision records (ADR, AgDR), specs (OpenSpec `openspec/`, design
   documents) touched or referenced by the pull request, and the reasons they give.
4. The diff itself: `git diff "$BASE"...HEAD --stat`, then the changed files.
5. For each item: the commented lines in context, their callers and callees (CodeGraph when it is
   available, otherwise search), and the tests that cover them.
6. Schemas and interfaces the item touches: database migrations and models, Pydantic or TypeScript
   models, CLI options, API signatures, data contracts, manifests.
7. Technical documentation: READMEs of the touched packages and commands, architecture documents.
8. Ecosystem rules: `pyproject.toml` and the linter configuration, `package.json` and its lint rules,
   lockfiles and pinned versions, the installed version of any library the comment relies on.

Check a reviewer's factual claims against the code and the installed dependencies, not against
diagrams, tickets, or memory. When a comment relies on a library behaviour, open the installed
package and confirm it. When a comment contradicts a decision record, the record wins unless the
comment shows the record is wrong.

## 4. Verdict per item

Give every item exactly one verdict:

| Verdict | When | Change in this PR |
|---|---|---|
| `accepted` | The comment is right and matters for this pull request: a bug, a contract break, a security or recovery gap, a violation of the project rules, a doc that is wrong. | Yes |
| `nice-to-have` | A sound recommendation the pull request does not need: style, a small refactor, extra robustness, a better name. | Depends on the mode below |
| `out-of-scope` | Touches a global behaviour, another component, or a new need this pull request was never asked to deliver. | No |
| `context-gap` | The reviewer lacks context on the project, the architecture, or the feature, and asks for something that contradicts them. | No |
| `not-applicable` | Wrong recommendation, misuse or misreading of the code, unsuited to the stack, or valid only for an older version of the project or of a library. | No |

Resolve `nice-to-have` items through the project mode:

- `--mode rush` (deliver fast): defer them, no change.
- `--mode polish` (architecture improvement, quality pass): accept them.
- No mode given: look for evidence first, in this order: the user's own words in this session, the
  memory entries about this repository, the ticket's urgency or deadline, the project instructions.
  Decide when the evidence is clear. When it is not, ask the user **once**, with `AskUserQuestion`,
  listing every `nice-to-have` item, offering rush or polish for the whole set and a per-item
  override. Never ask more than once per run.

Also decide, per item, whether the reply must ask something to a named audience (the comment's
author, a team, the science side, another maintainer). Mark it `needs-input` when a decision cannot
be taken without that answer; otherwise mark it `close`. Prefer taking the decision yourself from the
evidence: `needs-input` is for facts you cannot establish, not for approval of your answer.

## 5. Checkpoint: show the table, wait for the go-ahead

Present, in the chat, one table with a row per item:

    ID | author | file:line | comment (short) | verdict | why (one line) | planned change and commit scope | reply gist | close?

Below it, the commit plan: one line per planned commit with its Conventional Commit subject and the
items it covers. Then stop and wait. Do not commit, push, post, or resolve anything before the user
answers. Apply the user's corrections to the table, then execute from the corrected table.

## 6. Land the accepted items

For each accepted item, in the order of the table:

1. Make the smallest coherent change that answers the comment, following the repository's
   conventions and the decision records. Keep related documentation, specs, decision records, and
   READMEs in step; update them in the same commit when they describe the changed behaviour, or in a
   paired `docs` commit when they are large.
2. Add or adjust the tests that pin the change.
3. Commit it alone: one item per commit, Conventional Commits 1.0.0, a single subject line, no body,
   no trailer. Group several items in one commit only when one change answers them all.
4. Force-add files the repository ignores on purpose but tracks by convention (for example decision
   records under an ignored `docs/` path) when the project instructions say so.

Then run the project's checks once for the whole batch: prefer the `make` targets the project
documents (lint, format, unit tests, type checks); otherwise the ecosystem's tools (`uv run ruff`,
`uv run pytest`, `pre-commit run --all-files`; `npm run lint`, `npm test`). When the repository ships a
local end-to-end script for the touched command, run it. Fix what fails in the same commit that broke
it. Report pre-existing failures unrelated to the batch instead of fixing them.

Update the pull-request description when a change alters what it states (behaviour, counts,
migration numbers, usage), using the `pr-writer` skill and the same authorship rules.

Push with a plain push, never with force:

    git push origin "<headRefName>"

No accepted item means no commit and no push.

## 7. Reply on every item

Post one reply per item, after the push, so every hash you cite exists on the remote. Check it:

    git branch -r --contains <sha> | grep -q "origin/<headRefName>"

Reply shape, in English, two to five sentences:

1. **Open with the relevance level**, in plain words: `Valid, fixed.` / `Good catch.` /
   `Good point, deferred: …` / `Out of scope for this PR: …` / `Not applicable here: …` /
   `Different reading: …`.
2. **Justify**: what changed and why, or why nothing changes (the rule, the record, the code fact, the
   version). Cite the evidence the reviewer could not see: a decision record path, a contract, an
   installed version.
3. **Link every commit** that answers the item as `[<short>](https://github.com/<owner>/<repo>/commit/<full-sha>)`:

        FULL="$(git rev-parse <short>)"

4. **Ask the question** when the item is `needs-input`, addressed to the named audience, so the thread
   has a reason to stay open.

Post it:

    gh api -X POST "repos/$OWNER_REPO/pulls/$N/comments/<last-comment-databaseId>/replies" -f body="$BODY"

Items without a thread (review-body remarks, suppressed findings) get one pull-request comment
listing each with its verdict, justification and links:

    gh api -X POST "repos/$OWNER_REPO/issues/$N/comments" -f body="$BODY"

## 8. Resolve, or keep open on purpose

Resolve every thread whose item is `close`:

    gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id="<PRRT_id>"

Keep a thread open only when its reply asks a question to a named audience. Never leave a thread open
so that the author can approve the answer: assume the answer stands; the author re-opens the thread
or writes a new comment if it does not.

## 9. Report

In the chat, in French: the final table with verdicts and clickable commit links; the checks that ran
and their results; the pushed range (`HEAD_BEFORE..HEAD`); the threads left open and whom each one
waits for; what remains outside this run (CI on the new head, the reviewers' next pass). Reviewer
bots do not always re-review after a push: mention it, and do not wait for them.

## Arguments
$ARGUMENTS

Interpretation:
- Empty: the pull request of the checked-out branch, mode inferred or asked once.
- A number or a pull-request URL: that pull request.
- `--mode rush` or `--mode polish`: the project mode of section 4.
- Any other free text: steering from the user for this run (an item to ignore, a topic to treat as
  out of scope, a reviewer whose questions must stay open). Apply it, and reflect it in the table.
