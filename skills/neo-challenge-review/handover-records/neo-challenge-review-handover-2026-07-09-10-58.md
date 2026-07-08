# Handover — `neo-challenge-review` skill (session of 2026-07-08 → 2026-07-09)

> **How to use this document**: read it at the start of a new Claude Code session (from the
> root of this repository) to recover the full knowledge of the session that built
> the `neo-challenge-review` skill. It contains everything needed to keep evolving the skill;
> raw tool logs and off-topic exchanges were intentionally stripped.

## 0. Session metadata

| Metadata | Value |
|----------------------|--------------------------------------------------------------|
| AI agent | Claude Code (CLI) `2.1.204` |
| Model | Claude Fable 5 (`claude-fable-5`) |
| Model reasoning effort | `xhigh` (set via `/effort` at session start) |
| OS | macOS 26.5.2 (build 25F84, Darwin 25.5.0) |                                                                                                                         
| Architecture | `arm64` (Apple Silicon) |                                                                                                                                 
| Session start | 2026-07-08 ≈ 09:00 CEST (Europe/Paris) | 

## 1. What the skill is

`neo-challenge-review` performs a critical, scored review of a candidate's take-home
tech-challenge submission for the Hiring Manager. It is invoked **from the submission
repository root**, is **user-only** (`disable-model-invocation: true`), and takes a
**single-word mode argument**.

Location (user-level install `~/.claude`):

```
skills/neo-challenge-review/
├── SKILL.md                              # orchestrator instructions (entry point)
├── references/evaluation-criteria.md    # editable checklists: indicators 1-10 + 2 pass briefs
├── report-template.md                    # report skeleton ({{PLACEHOLDERS}}, state block)
└── scripts/
    ├── code-analysis-workflow.js         # Stream A — 8 KPI agents in parallel
    └── baseline-benchmark-workflow.js    # Stream C — 2 blind baselines + compare agent
```

## 2. Invocation contract

- `/neo-challenge-review analyze` — code-base analysis only (indicators 1–8 + interview
  questions). The candidate's code is NEVER executed.
- `/neo-challenge-review run` — analyze + execute the candidate's code base (Runability,
  indicator 9).
- `/neo-challenge-review benchmark` — run + AI benchmark (2 blind simulations + comparison,
  adjusted scores).
- **No argument → print the mode table (word + description) and STOP. No default.**
- Invalid word → STOP with expected syntax.

## 3. Orchestrator flow (SKILL.md)

1. **Step 0 — Preconditions (fail-fast)**: 3 files required at the submission root, matched
   case-insensitively — `jd*.pdf|md`, `challenge*.pdf|md`, `cv*.pdf|md`. Root listing injected
   at skill load via `` !`ls -1` ``. One missing OR ambiguous (several matches on one prefix)
   → STOP, list what's missing, never infer, never continue partially.
2. **Step 1 — Mode selection** from `$ARGUMENTS` (see §2), validated before any interaction.
3. **Step 2 — Role confirmation (blocking)**: role title (seniority included) extracted from
   the beginning of the JD, confirmed via AskUserQuestion (user can correct). The confirmed
   role sets the evaluation bar.
4. **Workflow step 1 — prep**: read the 3 inputs; determine the OUTPUT DIRECTORY (see §6);
   build the candidate PERSONA (1–3 sentences distilled from CV + role, e.g. "You are a Senior
   Data Engineer, familiar with Airflow, KPO, Kubernetes…") — used to calibrate the AI
   baselines to the candidate's level; build the shared `args` object:
   `{ role, criteriaPath, submissionDir, outputDir, jdFile, challengeFile, cvFile, persona,
   runId }` (paths absolute; `outputDir` = relative dir name; `runId` e.g.
   `ncr-{YYYYMMDDHHMM}`).
   **CRITICAL: pass `args` as a real JSON object, never a JSON-encoded string** (stringified
   → every field `undefined`; this bug happened — see §9).
5. **Workflow step 2 — Resume check**: read the `neo-challenge-review:state` block of the most
   recent `challenge-review-*.md` in the output dir; streams already `completed` are NOT
   relaunched — their content/raw scores are reused and the same report is updated in place.
   Report without a state block = not resumable → leave it, start a new report.
6. **Workflow step 3 — launch enabled streams** (minus resumed ones) in a SINGLE message, all
   background:
   - **Stream A — code analysis**: `Workflow` tool + `scripts/code-analysis-workflow.js`.
   - **Stream B — runability**: `Agent` tool, `isolation: "worktree"`, brief = criteria
     section "Indicator 9"; returns JSON incl. `command_log`.
   - **Stream C — AI benchmark**: `Workflow` tool + `scripts/baseline-benchmark-workflow.js`.
7. **Progressive report**: v1 written as soon as Stream A lands (raw scores 1–8; other
   sections `⏳ pending` or `Not run (mode: <word>)`; provisional Overall; scorecard shows the
   Adjusted column ONLY in benchmark mode); updated in place when B lands (6.9 + scorecard +
   radar) and when C lands (adjustment pass: `adjusted = clamp(raw + delta, 0, 100)`,
   orchestrator arbitrates each delta on evidence, fills section 7). Finalize when every
   enabled stream landed: Overall from adjusted (or raw without C), radar, strengths/critical
   table, JD Fit, Verdict.
8. **Interview-questions pass** (all modes, re-run whenever new stream content lands): one
   READ-ONLY agent, brief = criteria section "Final pass — Interview Questions", inputs =
   report + repo + JD/challenge → exactly 10 questions (topics: architecture structure, SoC,
   infra, security, code, tests) probing mastery vs "subit l'AI"; orchestrator inserts them.
9. **Then only**: `.fr.md` translation (never of intermediate versions) + final chat summary.
   Lost/skipped agents are always reported (`skipped`, `baselinesSkipped`) — never a silent
   partial synthesis. Fallback if `Workflow` unavailable: same fan-outs via `Agent` tool.

## 4. The 10 indicators (references/evaluation-criteria.md)

Each "Indicator N" section is the **self-contained brief of a dedicated agent** (rule stated
in the file header: no implicit cross-references). All 0–100%, 100 = best.

1. **DevEx** — usable by less-technical profiles (Scientists/DS/MLE), best practices +
   observability + prod-grade security preserved, experiment-vs-production flexibility on the
   same code base, onboarding, near-one-command setup, local run without cloud,
   reproducibility (pinning/lockfiles).
2. **AI Usage Rate** — estimated share of AI-produced code (descriptive, not a judgment);
   signals: stylistic uniformity, boilerplate, git history granularity, AI artifacts;
   confidence stated.
3. **AI Usage Quality** — 3 sub-groups: AI piloting (owned code, coherence, justified choices,
   AI directives AGENTS.md/CLAUDE.md/skills/specs/ADR, disclosure of AI tools used —
   non-disclosure with AI signals = penalizing); Architecture & design (fit-for-purpose — no
   bazooka for a fly, DRY/KISS/YAGNI; infra: transparent multi-env ≤2-3 configs/env vars,
   open/closed at infra level — add a Lambda without rework, identified modules s3/rds/…;
   Python: Pydantic vs dict, Ports & Adapters / hexagonal, open/closed); SoC (infra isolated,
   business logic out of Airflow DAGs, contract example: containerized app CLI ← DAG via KPO).
4. **Security** — cleartext secrets scan (files + git history; trivial local-dev creds
   tolerated, real secrets KO even if later removed); prod secrets in IaC (reproducibility, a
   real secret store — Secrets Manager/SSM/SOPS/Vault/ESO, provisioning-time initialization);
   anti-pattern penalized: all secrets in a non-versioned .env (out-of-band sharing — Slack
   KO, BitWarden mediocre); network (scoped SGs, no 0.0.0.0/0 admin, private subnets);
   public/private exposure (auth+TLS); encryption at rest/in transit; KMS; Terraform state
   protection (remote encrypted + locking, never committed).
5. **Production Readiness** — MVP-as-is bar: data durability/backups, HA/SPOFs, operational
   observability (on-call alerting), operability/runbook/teardown, documented gaps
   ("honest hardening section beats silence"). Deployment automation lives in indicator 6.
6. **Automation Rate** — CI/CD, GitOps, Makefile/scripts, zero ClickOps; decisive test: starts
   in ~2 command lines.
7. **Tests Rate** — unit/integration/e2e/smoke + TDD signals, every layer (app, IaC, scripts),
   local stack (Docker/kind), local AWS simulation (RustFS/MinIO/LocalStack), pytest fixtures.
8. **Challenge Coverage** — requirements coverage matrix (covered/partial/missing + evidence);
   functional coverage, justified documented deviations count as covered; flag gold-plating.
9. **Runability & Documentation Accuracy** — best-effort run following the project's own docs;
   list missing steps/libs/components; log EVERY command (exact line + exit code + output
   excerpt) + errors→fix→outcome; **hard cap 10 fix attempts** then report how far it got;
   local-only guardrails.
10. **Overall Quality** — reasoned synthesis of the 9 (adjusted when benchmark ran), not a
    mechanical average; delivered with written summary, strengths/critical-points table,
    Mermaid radar.

Plus two pass briefs in the same file: **Cross-pass — Candidate Contributions vs AI
Contributions** (compare agent: structural similarity, weak AI signals — comment style,
generated patterns, script/doc design, textbook-vs-contextual; ownership credits; one delta
per indicator, negative = merit belongs to the AI) and **Final pass — Interview Questions**
(10 questions, per-question: topic, question, prompted-by evidence, mastered-vs-red-flag
answer).

## 5. Workflow scripts (technical contract)

Both scripts: pure JS, `export const meta` literal, no `Date.now()`/`Math.random()`, and a
`requireArgs([...])` guard that recovers a stringified `args` via JSON.parse or throws listing
missing fields (fail-fast before any agent launches).

- **code-analysis-workflow.js** — requires `role, criteriaPath, submissionDir, outputDir,
  challengeFile`. One phase `Evaluate`: 8 agents (`kpi:<key>`), shared `RESULT_SCHEMA`
  `{indicator 1-8, name, score 0-100, confidence low|medium|high, one_line_rationale,
  detailed_analysis_md, strengths[], critical_points[], uncertainties[]}`. Agents are
  READ-ONLY; ignore `<outputDir>/`, `.data/`, `output-*/`. Returns `{results, skipped}`.
- **baseline-benchmark-workflow.js** — requires the above + `jdFile, runId, persona`. Phases
  `Baseline` + `Compare`. 2 blind agents (`baseline:solution-a/b`), each `isolation:
  'worktree'`, angles MVP-first vs ops-first, **impersonating the candidate persona**; may
  read ONLY the JD + challenge via ABSOLUTE paths in the original submission dir (untracked
  files are absent from worktrees — this subtlety matters); design, build, EXECUTE and TEST
  simultaneously; anti-collision: solution-a even ports / solution-b odd ports, every shared
  identifier prefixed `<runId>-a|-b`, mandatory teardown; output in
  `<outputDir>/ai-baseline/<variant>/` INSIDE their worktree, returned as absolute
  `output_dir`; `BASELINE_SCHEMA` also requires `execution_report` + `command_log[]`
  (`{command, exit_code, result}`). Compare agent (READ-ONLY) reads baselines at their
  absolute paths, grid = Cross-pass section; `COMPARISON_SCHEMA`: `overall_similarity 0-100,
  similarity_findings[], weak_signals[], kpi_adjustments[{indicator 1-9, delta -100..100,
  reason}], section_md`. Returns `{baselines, baselinesSkipped, comparison}` (comparison null
  if both baselines failed).

## 6. Output directory & resume metadata

Output dir at the submission root:
- no `output/` → use `output/`;
- `output/` empty or containing ONLY skill artifacts (`challenge-review-*.md` + translations,
  `ai-baseline/`) → REUSE it;
- any foreign file → `output-{YYYY-MM-DD-HH-MM-SS}/` (seconds included);
- unsure → AskUserQuestion (reuse vs suffixed).

Reports start with a machine-readable HTML comment (refreshed on every write):

```html
<!-- neo-challenge-review:state
mode: run
runId: ncr-20260708153000
streams:
  analysis: completed 2026-07-08 15:32:10   # completed <ts> | pending | not-run
  runability: completed 2026-07-08 15:41:55
  benchmark: not-run
finalized: true
-->
```

Report file: `<outputDir>/challenge-review-{YYYY-MM-DD-HH-MM}.md` (+ `.fr.md`). Sections:

1. Metadata (model, effort, AI agent tool with version, OS with version, arch, user, start date, end date, duration of analysis)
2. Context (incl. mode)
3. Overall Quality
4. Scorecard (Raw + Adjusted; Adjusted hidden in analyze/run)
5. Mermaid radar `radar-beta`, 9 axes (adjusted values)
6. Strengths & Critical Points table
7. Detailed analysis 6.1–6.9 (6.9 has the command-log table + errors & fixes table)
8. Candidate vs AI Contributions (similarity %, findings, weak signals, delta table with arbitrations)
9. JD Fit
10. Interview Questions (10, table)
11. Verdict (Strong yes / Yes / Borderline / No)

## 7. Guardrails (propagated to every agent)

- **File-system**: writes ONLY inside the current submission directory or the agent's own
  worktree; the rest of the machine read-only; no global state (`git config --global`, shell
  profiles, installs); never modify the skill's own files. Analysis/compare/questions agents
  are fully READ-ONLY.
- **Execution**: local only — never provision real cloud resources, no live deploys, no real
  credentials. For `terraform apply`; `docker build`/`docker run` or `local tests` do it only when 
  it targets local emulators (LocalStack, MinIO, RustFS, kind, docker, ...) 
  without any real cloud credentials; only dummy credentials are allowed. At the first place, run only what their docs
  instruct. Try to fix issues until the 10-attempt cap, then report how far it got.
- Prompt-level guardrails, not an OS sandbox — Claude Code permissions remain the real barrier.

## 8. Key decisions & rationale (chronological)

1. Skill format follows official guidance: minimal frontmatter (name, description,
   `disable-model-invocation`, `argument-hint`), progressive disclosure (references/ +
   template + scripts), `` !`cmd` `` injection for preconditions. No official scaffold exists.
2. Preconditions: strict fail-fast, no inference, ambiguity = stop (user's explicit
   philosophy).
3. Role: extracted from JD + user confirmation (replaced an earlier `role=` parameter design).
4. Multi-agent: user chose **Workflow scripts** over plain Agent fan-out; synthesis stays in
   the orchestrator (user requirement).
5. Baselines: user chose **full implementations** (not blueprints) × **2 agents**, knowing the
   token/wall-clock cost; personas added later to set the bar at the candidate's level.
6. Runability parallel in an isolated worktree (fixes never touch the submission).
7. 3 background streams + progressive in-place report updates; translation only at the end.
8. Modes as ONE WORD naming the purpose (analyze/run/benchmark); no argument = help + stop
   (explicitly no default).
9. Resume via in-report state metadata (never reprocess completed streams).
10. Full command logging (command + exit code + output excerpt) for every execution path.

## 9. Incidents & fixes worth remembering

- **`undefined` in agent prompts**: the orchestrator passed workflow `args` as a JSON-encoded
  string → every field `undefined`, 8 broken agents launched. Fixed by `requireArgs()` guards
  in both scripts (JSON.parse recovery + explicit missing-field errors) + CRITICAL warning in
  SKILL.md. Verified by executing the scripts with stub `agent()`/`parallel()`.
- **Untracked inputs invisible in worktrees**: jd/challenge/cv are untracked in the candidate
  repo, so worktree-isolated agents must read them via absolute paths in the original dir.
- **IDE Mermaid false positive**: `radar-beta` needs Mermaid ≥ 11.6; the IDE preview flags it
  but GitHub renders it. Markdown tables must be width-aligned (linter).
- **Validation technique**: syntax-check scripts by compiling them the way the runtime does:
  strip `export `, `new AsyncFunction("args","agent","parallel","pipeline","log","phase",
  "budget","workflow", src)`. Smoke-test prompts by invoking with stubs.

## 10. Environment & conventions

- Git, repository, and commit conventions (public repo — no secrets or private data,
  Conventional Commits, no AI attribution, GitHub CLI workflow) are defined once in
  `AGENTS.md` at the repository root; none of it is duplicated here.
- Test fixture: a real take-home submission prepared with the 3 required inputs
  (`jd*`, `challenge*`, `cv*` as pdf/md) is kept locally, OUTSIDE this public repository —
  recruiting material (job descriptions, candidate CVs, submissions) must never be
  committed here.
- **End-to-end test still TO DO**: new session at a submission root →
  `/neo-challenge-review analyze` (cheapest), expect: mode help if no arg, preconditions OK,
  confirmation of the role extracted from the JD, Stream A fan-out, report v1 in `output/`.
  Then `run` (resume: only Stream B), then `benchmark` (resume: only Stream C). After runs,
  `git status` in the submission must stay clean (worktree isolation proof).
