#!/usr/bin/env bash
# Test suite for gitleaks-guard.sh. Run: bash tests.sh
# Creates throwaway git repositories under mktemp; never touches real repos.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GUARD="$SCRIPT_DIR/gitleaks-guard.sh"
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0

hook_input() { # $1 = tool command, $2 = cwd
  jq -n --arg cmd "$1" --arg cwd "$2" \
    '{tool_name: "Bash", tool_input: {command: $cmd}, cwd: $cwd}'
}

assert_guard() { # $1 = test name, $2 = expected exit code, $3 = command, $4 = cwd, $5 = extra env PATH (optional)
  local name=$1 expected=$2 command=$3 cwd=$4 path=${5:-$PATH}
  local actual
  hook_input "$command" "$cwd" | PATH="$path" bash "$GUARD" >/dev/null 2>"$TMP_ROOT/stderr"
  actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $name — expected exit $expected, got $actual"
    sed 's/^/      stderr: /' "$TMP_ROOT/stderr"
    FAIL=$((FAIL + 1))
  fi
}

make_repo() { # $1 = dir
  git -C "$1" init -q
  git -C "$1" config user.email test@test.local
  git -C "$1" config user.name test
}

# Repo with a harmless staged change
CLEAN_REPO="$TMP_ROOT/clean"
mkdir -p "$CLEAN_REPO"
make_repo "$CLEAN_REPO"
echo "hello world" > "$CLEAN_REPO/notes.txt"
git -C "$CLEAN_REPO" add notes.txt

# Repo with a staged fake GitHub PAT (high-entropy, reliably matched by the
# github-pat rule). The token is split so this test file never contains the
# full pattern itself (GitHub push protection would flag it).
LEAKY_REPO="$TMP_ROOT/leaky"
mkdir -p "$LEAKY_REPO"
make_repo "$LEAKY_REPO"
printf 'github_token = %s%s\n' "ghp_" "Zqx8fT2LmA9bYc3VdW5eRg7HsJ4KpN6QuX1S" > "$LEAKY_REPO/config.ini"
git -C "$LEAKY_REPO" add config.ini

# PATH with jq but without gitleaks, for the fail-closed case
NOGITLEAKS_BIN="$TMP_ROOT/bin"
mkdir -p "$NOGITLEAKS_BIN"
for tool in jq git bash cat dirname; do
  ln -s "$(command -v "$tool")" "$NOGITLEAKS_BIN/$tool"
done

assert_guard "non-commit command is allowed"           0 "ls -la"                        "$CLEAN_REPO"
assert_guard "commit with clean staged changes passes" 0 'git commit -m "docs: notes"'   "$CLEAN_REPO"
assert_guard "commit with staged secret is blocked"    2 'git commit -m "add config"'    "$LEAKY_REPO"
assert_guard "missing gitleaks blocks (fail-closed)"   2 'git commit -m "anything"'      "$CLEAN_REPO" "$NOGITLEAKS_BIN:/usr/bin:/bin"

echo "----"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
