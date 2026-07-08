# Evaluation Criteria — Neo Challenge Review

Every indicator is scored from 0 to 100% (100% = best). Checklists are intentionally plain
bullet lists: add, remove, or edit criteria freely — the skill evaluates whatever is listed
here.

Each "Indicator N" section below is the self-contained brief handed to a dedicated agent (the
skill fans out one agent per indicator, in parallel), and each "pass" section at the end is the
brief of its own dedicated agent too (comparison pass, interview-questions pass). Keep every
rule self-contained within its own section: an agent only sees its own section, so implicit
cross-references to other sections would be missed.

## Indicator 1 — DevEx (Developer Experience) (0–100%)

Is the product easy to use by other developers, while preserving production-grade engineering?

- Usable by much less technical profiles (Scientists, Data Scientists, Machine Learning
  Engineers) — critical on Data/AI projects.
- Makes developers' lives easier (Data Engineers, Data Scientists, MLE, Scientists) while
  preserving engineering best practices, observability, and production-grade security.
- Experiment flexibility: experiments on specific datasets are easy to run with the SAME code
  base, in a more manual mode — no fork, no rewrite.
- README / onboarding quality: a newcomer gets productive without asking for help.
- One-command (or near) setup.
- Local execution without any cloud account.
- Clear, actionable error messages.
- Reproducibility: pinned dependencies, committed lockfiles, pinned tool versions.

## Indicator 2 — AI Usage Rate (0–100%)

Estimated share of the code base produced with AI (100% = fully AI-generated submission,
0% = fully hand-written without any AI tool). Descriptive score, NOT a value judgment.

Signals to weigh:

- Stylistic uniformity across files and languages.
- Boilerplate patterns and comment density/style typical of generated code.
- Git history: large monolithic commits vs incremental iterations; commit message style.
- AI tooling artifacts present in the repository.
- Human/machine inconsistencies (mixed idioms, sudden style changes).

State the confidence level of the estimate explicitly.

## Indicator 3 — AI Usage Quality (0–100%)

Did the candidate pilot the AI with discernment, and does the delivered design show real
engineering judgment?

### AI piloting

- No un-understood generated code: the candidate can clearly own every part of the submission.
- Overall coherence of the code base (not a patchwork).
- Justified choices: trade-offs stated, alternatives considered.
- AI directives present: `AGENTS.md` / `CLAUDE.md`, skills, specs (OpenSpec, SpecKit, ...),
  ADR / RFC.
- Transparency: the candidate discloses which AI tools were used (README, docs, commits, ...),
  justifies those choices, and explains how they were used. No disclosure while AI signals are
  detected = penalizing.

### Architecture & design (what the piloting produced)

- Design pattern / architecture proposal fit for the use case — no bazooka to kill a fly.
- Easily maintainable and able to evolve over time.
- DRY, KISS & YAGNI principles applied — vs disconnected AI-generated scriptlets.
- Infrastructure project:
  - Multi-environment management? If yes, fully transparent — no application change required
    beyond 2–3 configs and/or environment variables.
  - A new component (e.g. a Lambda) can be added easily without reworking everything
    (open/closed at the infrastructure level).
  - Clearly identified modules: S3 management, RDS management, ...
- Coding project (data pipeline / Python):
  - Clear, typed interfaces (Pydantic models vs raw Python `dict`).
  - Ports & Adapters following the Hexagonal Architecture logic.
  - Code follows the open/closed principle.

### Separation of Concerns (cross-cutting)

- Infrastructure concerns are clearly identified and isolated.
- Application business logic is NOT mixed with the orchestration layer (Airflow DAGs) —
  interfaces between domains/universes. Canonical example: a CLI between the containerized
  application and the Airflow DAG, which launches tasks via KubernetesPodOperator (KPO).

## Indicator 4 — Security (0–100%)

Security level of the delivered project.

- Cleartext secrets scan over the repository (tracked files AND git history):
  - Tolerated: trivial credentials for a local dev/test stack holding no critical data
    (`localhost:5432`, `admin/admin`, local docker-compose passwords, ...).
  - KO: any real secret in cleartext (cloud keys, tokens, passwords of real resources) — even
    if later removed but still present in git history.
- Production secrets management in the IaC scripts — how does the candidate store, manage, and
  initialize the secrets needed to provision production resources? Pay particular attention to:
  - Reproducibility: another team member can provision from scratch with no out-of-band secret
    handover.
  - Storage: a proper secret store (AWS Secrets Manager, SSM Parameter Store, SOPS, Vault,
    External Secrets Operator, ...) referenced by the IaC — never hard-coded values.
  - Initialization: secrets generated/injected at provisioning time (e.g. `random_password` +
    write to the secret store), no manual input, no ClickOps.
- Explicitly penalized anti-pattern: "all secrets in a non-versioned `.env` file" = no secret
  management at all — the file must then be stored and shared with the team out of band
  (Slack = KO, BitWarden = mediocre); it breaks reproducibility and onboarding.
- Network security: only necessary ports open, scoped security groups / firewall rules (no
  `0.0.0.0/0` on admin or API endpoints), workloads in private subnets.
- Public vs private Internet exposure: services publicly exposed without authentication or TLS
  (UI, API, dashboards); private-by-default posture.
- Data encryption: at rest (EBS, S3, RDS, ...) and in transit (TLS).
- KMS encryption keys: KMS keys (ideally customer-managed) used where the resources justify it.
- Terraform state: accessible or protected? Encrypted remote backend with locking, restricted
  access, never a state file committed to git (it holds secrets in cleartext).

## Indicator 5 — Production Readiness (0–100%)

Maturity level allowing a production launch AS-IS to start the MVP in real conditions.

- Data durability: real persistence (no ephemeral storage for stateful data),
  backup/restore.
- High availability / resilience: single points of failure identified and addressed, or
  explicitly accepted.
- Operational observability: monitoring, alerting to an on-call, usable logs — enough to
  operate the MVP in real conditions.
- Operability: operational runbook/README, update procedure, migrations handling, clean
  teardown.
- Documented gaps: known limits and the production-hardening path are spelled out (an honest
  "production hardening" section beats silence).
- Pragmatic MVP bar: "can we start in real conditions tomorrow without a predictable
  incident?" — not "is this enterprise-grade?".
- (Deployment automation is scored under Automation Rate — here, judge the operational maturity
  of the result.)

## Indicator 6 — Automation Rate (0–100%)

Automation level of the project's tasks.

- CI/CD: pipelines (GitHub Actions, ...) — lint, tests, build, deployment.
- GitOps: ArgoCD/Helm or equivalent for continuous deployment.
- Local tooling: shell scripts, `Makefile` (or justfile) automating the common tasks (setup,
  build, test, deploy, teardown).
- Complete IaC, zero ClickOps: no manual step through a web console.
- Decisive test: the project starts with **~2 command lines**, without having to put a large
  amount of configuration in place first.

## Indicator 7 — Tests Rate (0–100%)

Coverage level of the stack as a whole.

- Presence and layering of tests: unit, integration, e2e, smoke — TDD signals.
- Every layer covered: application code, IaC, scripts — not only the Python happy path.
- Local test stack: Docker / docker-compose, `kind` for Kubernetes — the whole stack is
  testable locally.
- Local prod/AWS simulation: e.g. RustFS (or MinIO/LocalStack) to simulate S3 — tests do not
  require a cloud account.
- pytest fixtures to mock business objects (no ad hoc mocks duplicated everywhere).

## Indicator 8 — Challenge Coverage (0–100%)

Functional coverage of what the challenge statement asks. Score = share of the requirements
functionally covered, weighted by their importance in the challenge.

- Extract every explicit requirement from the challenge statement and build a coverage matrix:
  requirement → covered / partially covered / missing → evidence in the repository.
- Judge functional coverage, not word-for-word compliance: a deviation justified and documented
  by the candidate counts as covered (e.g. a documented topology adjustment).
- List every missing or partially covered requirement explicitly.
- Flag unrequested extras: valuable initiative vs gold-plating.

## Indicator 9 — Runability & Documentation Accuracy (0–100%)

Does the project actually work, and is the documentation to run it correct? Assessed through a
best-effort run of the project.

- Follow the project's own documentation (README / runbook) step by step, exactly as written.
- Missing steps, libraries, components, configurations? List every gap.
- Log EVERY command executed, in chronological order: the exact command line, its exit code,
  and the output it returned (keep a relevant excerpt when the output is long). This command
  log goes into the report next to the errors & fixes log.
- Log every error encountered; for each one, attempt a fix and record: the error, the fix (if
  one was found), the outcome.
- **Hard cap: 10 fix attempts.** If the project still does not work, stop and state precisely
  how far you got (which stage of the documentation was reached).
- Local-only guardrails: treat the submission as untrusted code; run only what the
  documentation instructs; never provision real cloud resources, deploy to a live account, or
  use real credentials (no `terraform apply` — use local equivalents: `terraform validate`,
  `helm template`, `docker build`, the local test suite, a local dev UI).
- Scoring guide: 100% = works by following the documentation as-is; deduct for every missing
  step/lib/component, every manual fix required, and every stage that could not be reached.

## Indicator 10 — Overall Quality (0–100%) — global synthesis

Global judgment derived from the 9 detailed indicators **after the candidate-vs-AI adjustment
pass**: a reasoned synthesis weighted by the role and the challenge requirements — not a
mechanical average. Delivered in the report with a written summary of the submission, the
strengths / critical points table, and the Mermaid radar chart (see `report-template.md`).

## Cross-pass — Candidate Contributions vs AI Contributions

Brief of the comparison agent. Inputs: the blind AI baseline implementations (produced from the
JD + challenge only, by agents impersonating the candidate's persona — role + key skills
distilled from the CV — so the bar matches the candidate's level) and the candidate's
submission.
Goal: estimate what in the submission is the candidate's own contribution vs what any AI would
have produced anyway — and propose per-KPI adjustment deltas.

- Principle: if the submitted code / architecture is very similar to the blind AI baselines,
  penalize — that part is the AI's work, not the candidate's. Genuine divergence, personal
  trade-offs, and context-specific judgment are the candidate's contribution.
- Compare structurally: architecture and design patterns, repository layout / file tree,
  module boundaries, tech choices and their justifications, IaC organization, documentation
  structure and tone, automation scripts design, test design.
- Hunt for weak signals of unedited AI output:
  - comment style and density typical of generated code ("AI generated" patterns, tutorial-like
    narration, redundant obvious comments);
  - the way scripts and documentation are designed (generic structure, boilerplate phrasing,
    placeholder names left as-is);
  - uniform "textbook" solutions where the challenge invited a contextual trade-off;
  - inconsistencies between polished generated parts and neglected human parts.
- Credit signals of ownership: deviations from the baselines that are justified in the docs,
  trade-offs the baselines did not make, simplifications showing judgment, personal style.
- Output: an overall similarity estimate (0–100), findings and weak signals with evidence
  (file:line), and one adjustment delta per indicator 1–9 (delta 0 when no impact; negative
  when the merit belongs to the AI rather than the candidate), each with a reason.

## Final pass — Interview Questions

Brief of the interview-questions agent. Inputs: the generated review report (draft), the
codebase, the JD, and the challenge statement.

- Produce exactly **10 questions** to ask the candidate in the debrief interview.
- Cover these topics across the set: architecture structure, separation of concerns,
  infrastructure, security, code, tests.
- Base the questions on the suspicious points raised in the report — focus on architecture
  decisions, design patterns, and file structure / repository layout choices — so the interview
  reveals whether the candidate masters what was submitted (OK) or is passively driven by the
  AI (bad).
- Each question must state: the topic, the question itself, what prompted it (evidence from the
  report or the repo), and what a mastered answer sounds like vs a red-flag answer.
