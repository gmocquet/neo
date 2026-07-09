#!/usr/bin/env bash
# Claude Code PreToolUse hook: block `git commit` and `gh pr create/edit`
# commands whose message or description carries an AI attribution
# (Co-Authored-By: Claude, "Generated with Claude Code", "Powered by Claude", ...).
#
# Contract (https://docs.claude.com/en/docs/claude-code/hooks):
#   - receives the tool-call JSON on stdin;
#   - exit 0 allows the tool call;
#   - exit 2 blocks it, and stderr is fed back to the agent.
#
# The check runs on the command string itself, which is where agents put the
# message (`git commit -m ...`, `gh pr create --body ...`). A message edited
# interactively or read from a file (-F) is not visible here — acceptable, as
# the threat model is the agent authoring the attribution inline.

set -u

# Attribution-specific phrasings only — a plain mention of Claude/Claude Code
# in a commit message must NOT trigger.
ATTRIBUTION_PATTERNS=(
  'co-authored-by:[^"]*(claude|anthropic)'
  '(generated|written|created|authored) (with|by)[^"]*(claude|anthropic)'
  'powered by[^"]*claude'
  'claude-session:'
)

is_commit_or_pr() {
  local command=$1
  [[ "$command" =~ git([[:space:]]+[^[:space:]]+)*[[:space:]]+commit ]] ||
    [[ "$command" =~ gh[[:space:]]+pr[[:space:]]+(create|edit) ]]
}

find_attribution() { # prints the first matching pattern, returns 1 if none match
  local command=$1 pattern
  for pattern in "${ATTRIBUTION_PATTERNS[@]}"; do
    if grep -qiE "$pattern" <<<"$command"; then
      echo "$pattern"
      return 0
    fi
  done
  return 1
}

main() {
  local input tool_name command matched
  input=$(cat)
  tool_name=$(jq -r '.tool_name // empty' <<<"$input")
  [[ "$tool_name" == "Bash" ]] || return 0
  command=$(jq -r '.tool_input.command // empty' <<<"$input")
  is_commit_or_pr "$command" || return 0
  if matched=$(find_attribution "$command"); then
    {
      echo "no-ai-attribution-on-commit: AI attribution detected — command blocked."
      echo "Matched pattern: $matched"
      echo "This repository's convention (see AGENTS.md) forbids AI attribution in commits and PRs:"
      echo "no 'Co-Authored-By: Claude', no 'Generated with Claude Code', no 'Powered by Claude'."
      echo "Rewrite the message without the attribution, then retry."
    } >&2
    return 2
  fi
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
  exit $?
fi
