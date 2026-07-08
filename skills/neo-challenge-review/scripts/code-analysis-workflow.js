export const meta = {
  name: 'neo-challenge-review-code-analysis',
  description: 'Score the 8 code-analysis review indicators (one agent per KPI) in parallel — no execution, no baselines',
  phases: [
    { title: 'Evaluate', detail: 'one agent per indicator (1-8); runability and benchmark run in separate streams' },
  ],
}

// Expected args (provided by the orchestrating skill):
// { role, criteriaPath, submissionDir, jdFile, challengeFile, cvFile, runId }
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
const cfg = requireArgs(['role', 'criteriaPath', 'submissionDir', 'outputDir', 'challengeFile'])

const RESULT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: [
    'indicator', 'name', 'score', 'confidence', 'one_line_rationale',
    'detailed_analysis_md', 'strengths', 'critical_points', 'uncertainties',
  ],
  properties: {
    indicator: { type: 'integer', minimum: 1, maximum: 8 },
    name: { type: 'string' },
    score: { type: 'integer', minimum: 0, maximum: 100 },
    confidence: { type: 'string', enum: ['low', 'medium', 'high'] },
    one_line_rationale: { type: 'string' },
    detailed_analysis_md: {
      type: 'string',
      description: 'Report-ready markdown for this indicator\'s detailed section. Evidence cited as file:line. Indicator 8 embeds the requirements coverage matrix table.',
    },
    strengths: { type: 'array', items: { type: 'string' } },
    critical_points: { type: 'array', items: { type: 'string' } },
    uncertainties: { type: 'array', items: { type: 'string' } },
  },
}

const INDICATORS = [
  { n: 1, key: 'devex', name: 'DevEx (Developer Experience)' },
  {
    n: 2, key: 'ai-rate', name: 'AI Usage Rate',
    extra: 'Inspect the git history (commit style, granularity) and AI tooling artifacts. The score is descriptive, not a value judgment; state the confidence of your estimate explicitly.',
  },
  { n: 3, key: 'ai-quality', name: 'AI Usage Quality' },
  {
    n: 4, key: 'security', name: 'Security',
    extra: 'Scan tracked files AND the full git history for cleartext secrets, as your checklist specifies.',
  },
  { n: 5, key: 'prod-readiness', name: 'Production Readiness' },
  { n: 6, key: 'automation', name: 'Automation Rate' },
  { n: 7, key: 'tests', name: 'Tests Rate' },
  {
    n: 8, key: 'coverage', name: 'Challenge Coverage',
    extra: `The challenge statement is the file "${cfg.challengeFile}" at the submission root. Extract every explicit requirement from it and build the coverage matrix (requirement -> covered / partial / missing -> evidence) inside detailed_analysis_md.`,
  },
]

function buildKpiPrompt(ind) {
  return [
    `You are evaluating ONE dimension of a take-home tech-challenge submission for the role: ${cfg.role}.`,
    `The submission repository is the current working directory (${cfg.submissionDir}).`,
    `Ignore the \`${cfg.outputDir}/\` directory (this run's review artifacts) and any \`.data/\` or \`output-*/\` directories left by previous review runs — they are not the candidate's work.`,
    '',
    `1. Read the file ${cfg.criteriaPath} and locate the section "Indicator ${ind.n} — ${ind.name}".`,
    '   That checklist is your ONLY evaluation grid — do not evaluate anything outside it.',
    '2. Analyze the submission against every item of that checklist.',
    ind.extra ? `3. Indicator-specific instructions: ${ind.extra}` : null,
    '',
    'READ-ONLY GUARDRAIL: do not create, modify, or delete any file or directory — anywhere on this machine. Your only output is your structured result.',
    'Independence: the other dimensions are evaluated by other agents — do not speculate about them and do not score them.',
    'Back every claim with concrete evidence from the repository (cite file:line where relevant).',
    'List whatever you could not verify in `uncertainties`.',
    `Return your result through the structured output format: indicator=${ind.n}, name="${ind.name}", an integer score 0-100 (100 = best), confidence, a one-line rationale, and detailed_analysis_md ready to paste as this indicator's detailed report section.`,
  ].filter(Boolean).join('\n')
}

log(`Fanning out ${INDICATORS.length} code-analysis agents for role: ${cfg.role}`)

const results = (await parallel(INDICATORS.map(ind => () =>
  agent(buildKpiPrompt(ind), {
    label: `kpi:${ind.key}`,
    phase: 'Evaluate',
    schema: RESULT_SCHEMA,
  })
))).filter(Boolean)

const skipped = INDICATORS.length - results.length
if (skipped > 0) {
  log(`WARNING: ${skipped} indicator agent(s) returned no result — the synthesis must mention it`)
}

return { results, skipped }
