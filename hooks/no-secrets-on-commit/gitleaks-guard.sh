#!/usr/bin/env bash
# Claude Code PreToolUse hook: block `git commit` when gitleaks finds secrets
# in the staged changes.
#
# Contract (https://docs.claude.com/en/docs/claude-code/hooks):
#   - receives the tool-call JSON on stdin;
#   - exit 0 allows the tool call;
#   - exit 2 blocks it, and stderr is fed back to the agent.
#
# Known limitation: the scan runs in the session cwd reported by the harness,
# so a compound command such as `cd /elsewhere && git commit` is scanned in the
# wrong directory. Commits issued from the session working directory — the
# normal agent behavior — are always covered.

set -u

is_git_commit() {
  local command=$1
  [[ "$command" =~ git([[:space:]]+[^[:space:]]+)*[[:space:]]+commit ]]
}

scan_staged() {
  local workdir=$1
  if ! command -v gitleaks >/dev/null 2>&1; then
    echo "no-secrets-on-commit: gitleaks is not installed — blocking commit (fail-closed). Install it with: brew install gitleaks" >&2
    return 2
  fi
  local report
  if ! report=$(cd "$workdir" && gitleaks git --pre-commit --staged --redact --no-banner --no-color -v 2>&1); then
    {
      echo "no-secrets-on-commit: gitleaks flagged the staged changes — commit blocked."
      echo "$report"
      echo "Remove the secret, or allowlist a known-fake credential via the repo's .gitleaks.toml / a 'gitleaks:allow' comment, then retry."
    } >&2
    return 2
  fi
  return 0
}

main() {
  local input tool_name command cwd
  input=$(cat)
  tool_name=$(jq -r '.tool_name // empty' <<<"$input")
  [[ "$tool_name" == "Bash" ]] || return 0
  command=$(jq -r '.tool_input.command // empty' <<<"$input")
  is_git_commit "$command" || return 0
  cwd=$(jq -r '.cwd // empty' <<<"$input")
  [[ -n "$cwd" && -d "$cwd" ]] || cwd=$PWD
  scan_staged "$cwd"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
  exit $?
fi
