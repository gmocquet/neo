export const meta = {
  name: 'neo-challenge-review-benchmark',
  description: 'Build 2 blind AI baseline implementations concurrently (isolated worktrees), then benchmark the candidate submission against them',
  phases: [
    { title: 'Baseline', detail: '2 blind agents design, build, execute and test the challenge simultaneously in isolated worktrees' },
    { title: 'Compare', detail: 'candidate contributions vs AI contributions, KPI adjustment deltas' },
  ],
}

// Expected args (provided by the orchestrating skill):
// { role, criteriaPath, submissionDir, jdFile, challengeFile, cvFile, runId }
// runId: short unique id for this review run (e.g. "ncr-202607081530"); it namespaces
// every shared resource the two baseline simulations create while running concurrently.
// args MUST be a real JSON object — a JSON-encoded string makes every field undefined.
function requireArgs(names) {
  let a = args
  if (typeof a === 'string') {
    try { a = JSON.parse(a) } catch (e) {
      throw new Error('Workflow args arrived as a non-JSON string — pass args as a real JSON object (see SKILL.md step 1)')
    }
  }
  if (!a || typeof a !== 'object') {
    throw new Error('Workflow args are missing — pass the args object described in SKILL.md step 1')
  }
  const missing = names.filter(n => !a[n])
  if (missing.length > 0) {
    throw new Error(`Missing required workflow args: ${missing.join(', ')} — pass the args object described in SKILL.md step 1`)
  }
  return a
}
const cfg = requireArgs(['role', 'criteriaPath', 'submissionDir', 'outputDir', 'jdFile', 'challengeFile', 'runId', 'persona'])

const BASELINE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['variant', 'output_dir', 'approach_summary', 'tech_choices', 'repo_tree', 'key_decisions', 'execution_report', 'command_log'],
  properties: {
    variant: { type: 'string' },
    output_dir: { type: 'string', description: 'ABSOLUTE path of the produced implementation (inside the agent worktree)' },
    approach_summary: { type: 'string' },
    tech_choices: { type: 'array', items: { type: 'string' } },
    repo_tree: { type: 'string', description: 'The file tree of the produced implementation' },
    key_decisions: { type: 'array', items: { type: 'string' } },
    execution_report: { type: 'string', description: 'What was built, executed, and tested locally, with the results (and the teardown performed)' },
    command_log: {
      type: 'array',
      description: 'Every command executed, in chronological order',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['command', 'exit_code', 'result'],
        properties: {
          command: { type: 'string', description: 'The exact command line executed' },
          exit_code: { type: 'integer' },
          result: { type: 'string', description: 'Returned output — a relevant excerpt when long' },
        },
      },
    },
  },
}

const COMPARISON_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['overall_similarity', 'similarity_findings', 'weak_signals', 'kpi_adjustments', 'section_md'],
  properties: {
    overall_similarity: {
      type: 'integer', minimum: 0, maximum: 100,
      description: '100 = the submission is essentially what a blind AI produces for this challenge',
    },
    similarity_findings: { type: 'array', items: { type: 'string' } },
    weak_signals: { type: 'array', items: { type: 'string' } },
    kpi_adjustments: {
      type: 'array',
      description: 'One entry per indicator 1-9 (delta 0 when no impact)',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['indicator', 'delta', 'reason'],
        properties: {
          indicator: { type: 'integer', minimum: 1, maximum: 9 },
          delta: { type: 'integer', minimum: -100, maximum: 100 },
          reason: { type: 'string' },
        },
      },
    },
    section_md: {
      type: 'string',
      description: 'Report-ready markdown for the "Candidate Contributions vs AI Contributions" section',
    },
  },
}

// Two independent blind reference implementations, with lightly diverged
// engineering angles to cover more of the AI solution space. They run, build,
// and test SIMULTANEOUSLY on the same machine: solution-a only uses even port
// numbers and the "<runId>-a" prefix, solution-b odd ports and "<runId>-b".
const BASELINES = [
  { variant: 'solution-a', suffix: '-a', portParity: 'even', angle: 'Make pragmatic, MVP-first engineering choices.' },
  { variant: 'solution-b', suffix: '-b', portParity: 'odd', angle: 'Make production-operations-first engineering choices.' },
]

function buildBaselinePrompt(b) {
  const prefix = `${cfg.runId}${b.suffix}`
  const outputDir = `${cfg.outputDir}/ai-baseline/${b.variant}`
  return [
    'You are producing a BLIND AI reference implementation of a take-home tech challenge.',
    `WHO YOU ARE: ${cfg.persona}`,
    'Adopt this persona for every engineering decision: deliver what such a profile would realistically deliver — no more, no less. (The persona was distilled from the candidate\'s CV by the orchestrator; it tells you who you are, nothing about what the candidate submitted.)',
    'You know NOTHING about any candidate submission, and it must stay that way:',
    '- You run inside an isolated git worktree that contains an unrelated checked-out repository: IGNORE its content entirely. Do not read, list, or open anything in it outside your own output directory. Do NOT look at the git history.',
    `- The ONLY two input files you may read are "${cfg.submissionDir}/${cfg.jdFile}" and "${cfg.submissionDir}/${cfg.challengeFile}" (absolute paths — these files do not exist in your worktree).`,
    '',
    `1. Read the job description and the challenge statement from the two files above.`,
    `2. DESIGN and BUILD a complete implementation of the challenge — application code, IaC, documentation, tests, automation — inside ${outputDir}/ in your worktree (create it). Deliver at the level your persona (a ${cfg.role}) would realistically deliver: calibrate depth and rigor to that profile.`,
    `3. ${b.angle}`,
    '4. EXECUTE and TEST your implementation locally: build the images, start the local stack, run the test suite. Another simulation runs on this machine AT THE SAME TIME — collisions are prevented by these MANDATORY rules:',
    `   - PORTS: use ${b.portParity}-numbered ports ONLY (host ports, published container ports, NodePorts, port-forwards, local registry ports).`,
    `   - NAMES: prefix EVERY shared-resource identifier with "${prefix}": Docker containers, networks, volumes, image tags, compose project names, kind cluster names, Kubernetes namespaces, temp directories.`,
    '   - TEARDOWN: stop and remove everything you started (containers, clusters, networks, volumes) before finishing.',
    '   - COMMAND LOG: record EVERY command you execute (build, run, test, teardown), in order, with its exit code and a relevant excerpt of its output — returned in command_log.',
    '',
    'GUARDRAILS: local only — never provision real cloud resources, deploy to a live account, or use real credentials; no `terraform apply` (validate locally: terraform validate, helm template, docker build, local tests).',
    'FILE-SYSTEM GUARDRAIL: create, modify, or delete files ONLY inside your own worktree; everything else on this machine is strictly read-only; never change global state (git config --global, shell profiles, tool installs).',
    `Return through the structured output format: variant="${b.variant}", output_dir as the ABSOLUTE path of ${outputDir} inside your worktree, a summary of your approach, your tech choices, the file tree you produced, your key decisions, an execution report (what you built, ran, tested — with results — and the teardown performed), and the command_log (every command with exit code and output excerpt).`,
  ].join('\n')
}

function buildComparePrompt(baselines) {
  return [
    `Two blind AI reference implementations of the same tech challenge were produced from the JD + challenge statement only, by agents impersonating the candidate's profile — "${cfg.persona}" (role: ${cfg.role}). Each lives at the ABSOLUTE output_dir given in its self-reported summary below (they were built in isolated worktrees):`,
    '',
    JSON.stringify(baselines, null, 2),
    '',
    'READ-ONLY GUARDRAIL: do not create, modify, or delete any file or directory — anywhere on this machine. Your only output is your structured result.',
    `Critically compare the CANDIDATE's submission — the current repository, EXCLUDING the \`${cfg.outputDir}/\` directory and any \`.data/\` or \`output-*/\` review-artifact directories — against these AI references.`,
    `Your evaluation grid is the section "Cross-pass — Candidate Contributions vs AI Contributions" of ${cfg.criteriaPath}; read it and apply every item. Read the baseline implementations on disk at their output_dir paths, do not rely only on the summaries above.`,
    '',
    'Return through the structured output format: overall_similarity (0-100), similarity_findings, weak_signals, kpi_adjustments (one entry per indicator 1-9; delta 0 when no impact; negative delta = the merit belongs to the AI, not the candidate), and section_md (report-ready markdown for the "Candidate Contributions vs AI Contributions" report section).',
  ].join('\n')
}

log(`Fanning out ${BASELINES.length} blind baseline agents for role: ${cfg.role}`)

const baselines = (await parallel(BASELINES.map(b => () =>
  agent(buildBaselinePrompt(b), {
    label: `baseline:${b.variant}`,
    phase: 'Baseline',
    schema: BASELINE_SCHEMA,
    isolation: 'worktree',
  })
))).filter(Boolean)

let comparison = null
if (baselines.length > 0) {
  comparison = await agent(buildComparePrompt(baselines), {
    label: 'compare:candidate-vs-ai',
    phase: 'Compare',
    schema: COMPARISON_SCHEMA,
  })
} else {
  log('WARNING: both baseline agents failed — no candidate-vs-AI comparison available')
}

return {
  baselines,
  baselinesSkipped: BASELINES.length - baselines.length,
  comparison,
}
