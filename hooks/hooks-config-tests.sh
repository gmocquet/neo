#!/usr/bin/env bash
# Test suite for hooks-config.sh. Run: bash hooks-config-tests.sh
# Operates on throwaway settings files via CLAUDE_SETTINGS_FILE; never touches
# the real ~/.claude/settings.json.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MANAGER="$SCRIPT_DIR/hooks-config.sh"
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

GUARD_CMD="$SCRIPT_DIR/no-secrets-on-commit/gitleaks-guard.sh"
ATTR_CMD="$SCRIPT_DIR/no-ai-attribution-on-commit/attribution-guard.sh"
PASS=0
FAIL=0

check() { # $1 = test name, $2 = jq assertion, $3 = settings file
  if jq -e "$2" "$3" >/dev/null 2>&1; then
    echo "PASS  $1"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $1 — assertion: $2"
    sed 's/^/      /' "$3"
    FAIL=$((FAIL + 1))
  fi
}

# 1. add on a missing file creates it with only our hooks (one Bash matcher group)
S1="$TMP_ROOT/missing/settings.json"
CLAUDE_SETTINGS_FILE="$S1" bash "$MANAGER" add >/dev/null
check "add creates the settings file"      '(keys == ["hooks"]) and (.hooks | keys == ["PreToolUse"]) and (.hooks.PreToolUse | length == 1)' "$S1"
check "add registers every repo hook"      "[.hooks.PreToolUse[].hooks[].command] | sort == ([\"$ATTR_CMD\", \"$GUARD_CMD\"] | sort)" "$S1"

# 2. add is idempotent
CLAUDE_SETTINGS_FILE="$S1" bash "$MANAGER" add >/dev/null
check "add twice registers a single entry" "[.hooks.PreToolUse[].hooks[] | select(.command == \"$GUARD_CMD\")] | length == 1" "$S1"

# 3. add preserves an existing config, including foreign hooks on the same matcher
S2="$TMP_ROOT/existing.json"
cat > "$S2" <<'EOF'
{
  "model": "opus",
  "permissions": {"allow": ["Bash(ls:*)"]},
  "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "/elsewhere/other.sh"}]}]}
}
EOF
CLAUDE_SETTINGS_FILE="$S2" bash "$MANAGER" add >/dev/null
check "add keeps unrelated settings keys"  '.model == "opus" and .permissions.allow == ["Bash(ls:*)"]' "$S2"
check "add keeps foreign hooks"            '[.hooks.PreToolUse[].hooks[].command] | index("/elsewhere/other.sh") != null' "$S2"
check "add appends ours next to them"      "[.hooks.PreToolUse[].hooks[].command] | index(\"$GUARD_CMD\") != null" "$S2"

# 4. remove deletes only our hook
CLAUDE_SETTINGS_FILE="$S2" bash "$MANAGER" remove >/dev/null
check "remove keeps foreign hooks"         '[.hooks.PreToolUse[].hooks[].command] == ["/elsewhere/other.sh"]' "$S2"
check "remove keeps unrelated settings"    '.model == "opus"' "$S2"

# 5. remove without our hook present is a harmless no-op
CLAUDE_SETTINGS_FILE="$S2" bash "$MANAGER" remove >/dev/null
check "remove is idempotent"               '[.hooks.PreToolUse[].hooks[].command] == ["/elsewhere/other.sh"]' "$S2"

# 6. add then remove on a fresh file leaves an empty object (structures cleaned up)
S3="$TMP_ROOT/roundtrip.json"
CLAUDE_SETTINGS_FILE="$S3" bash "$MANAGER" add >/dev/null
CLAUDE_SETTINGS_FILE="$S3" bash "$MANAGER" remove >/dev/null
check "remove cleans empty hook structures" '. == {}' "$S3"

# 7. an invalid settings file is never overwritten
S4="$TMP_ROOT/broken.json"
echo '{not json' > "$S4"
if CLAUDE_SETTINGS_FILE="$S4" bash "$MANAGER" add >/dev/null 2>&1; then
  echo "FAIL  invalid settings file aborts"
  FAIL=$((FAIL + 1))
else
  if [[ "$(cat "$S4")" == '{not json' ]]; then
    echo "PASS  invalid settings file aborts untouched"
    PASS=$((PASS + 1))
  else
    echo "FAIL  invalid settings file was modified"
    FAIL=$((FAIL + 1))
  fi
fi

echo "----"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
