#!/usr/bin/env bash
# Test suite for attribution-guard.sh. Run: bash tests.sh
# Pure command-string analysis — no git repository needed.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GUARD="$SCRIPT_DIR/attribution-guard.sh"

PASS=0
FAIL=0

assert_guard() { # $1 = test name, $2 = expected exit code, $3 = tool command
  local name=$1 expected=$2 command=$3
  local actual
  jq -n --arg cmd "$command" '{tool_name: "Bash", tool_input: {command: $cmd}, cwd: "/tmp"}' \
    | bash "$GUARD" >/dev/null 2>&1
  actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $name — expected exit $expected, got $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_guard "non-commit command is allowed" 0 \
  'ls -la'

assert_guard "clean commit passes" 0 \
  'git commit -m "feat(auth): add SSO login"'

assert_guard "legitimate Claude Code mention passes" 0 \
  'git commit -m "docs(readme): explain Claude Code settings registration"'

assert_guard "Co-Authored-By Claude trailer is blocked" 2 \
  'git commit -m "feat: add feature

Co-Authored-By: Claude <noreply@anthropic.com>"'

assert_guard "Generated with Claude Code footer is blocked" 2 \
  'git commit -m "fix: bug

🤖 Generated with [Claude Code](https://claude.com/claude-code)"'

assert_guard "compound command with attribution is blocked" 2 \
  'git add -A && git commit -m "chore: update

Co-authored-by: Claude Fable 5 <noreply@anthropic.com>"'

assert_guard "gh pr create with powered-by body is blocked" 2 \
  'gh pr create --title "feat: x" --body "Adds X. Powered by Claude Code."'

assert_guard "gh pr edit with generated-with body is blocked" 2 \
  'gh pr edit 42 --body "Generated with Claude Code"'

assert_guard "clean gh pr create passes" 0 \
  'gh pr create --title "feat: x" --body "Adds X end to end."'

echo "----"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
