#!/usr/bin/env bash
# Register/unregister this repository's hooks in the user's Claude Code settings.
#
# Usage: hooks-config.sh add|remove
#
# Each hooks/<name>/hook.json declares one hook: {event, matcher, hook}, where
# "{{HOOK_DIR}}" inside the hook definition expands to the hook's absolute
# directory. Only entries whose command points into this repository are ever
# added or removed — the rest of the settings file is left untouched.
#
# The target file defaults to ~/.claude/settings.json and can be overridden
# with CLAUDE_SETTINGS_FILE (used by the tests).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SETTINGS_FILE=${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}

ensure_settings_file() {
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    echo '{}' > "$SETTINGS_FILE"
    echo "CREATE  $SETTINGS_FILE"
  fi
  if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
    echo "ERROR  $SETTINGS_FILE is not valid JSON — fix it manually before retrying." >&2
    return 1
  fi
}

write_settings() { # $1 = new JSON content
  local tmp="$SETTINGS_FILE.tmp.$$"
  printf '%s\n' "$1" > "$tmp"
  jq empty "$tmp"
  mv "$tmp" "$SETTINGS_FILE"
}

resolve_hook() { # $1 = hook.json path; prints the hook definition with {{HOOK_DIR}} expanded
  local meta=$1 hook_dir
  hook_dir=$(cd "$(dirname "$meta")" && pwd)
  jq -c --arg dir "$hook_dir" \
    '.hook | walk(if type == "string" then gsub("\\{\\{HOOK_DIR\\}\\}"; $dir) else . end)' "$meta"
}

add_hook() { # $1 = hook.json path
  local meta=$1 event matcher hookdef cmd result
  event=$(jq -re '.event' "$meta")
  matcher=$(jq -re '.matcher' "$meta")
  hookdef=$(resolve_hook "$meta")
  cmd=$(jq -r '.command' <<<"$hookdef")
  result=$(jq --arg event "$event" --arg matcher "$matcher" --arg cmd "$cmd" --argjson hookdef "$hookdef" '
    .hooks //= {}
    | .hooks[$event] //= []
    | if any(.hooks[$event][]; .matcher == $matcher) then
        .hooks[$event] |= map(
          if .matcher == $matcher
          then .hooks = ((.hooks // []) | if any(.[]; .command == $cmd) then . else . + [$hookdef] end)
          else .
          end)
      else
        .hooks[$event] += [{matcher: $matcher, hooks: [$hookdef]}]
      end' "$SETTINGS_FILE")
  write_settings "$result"
  echo "ADD     $event/$matcher -> $cmd"
}

remove_hook() { # $1 = hook.json path
  local meta=$1 event cmd result
  event=$(jq -re '.event' "$meta")
  cmd=$(resolve_hook "$meta" | jq -r '.command')
  result=$(jq --arg event "$event" --arg cmd "$cmd" '
    if (.hooks[$event] // null) == null then .
    else
      .hooks[$event] |= map(.hooks = ((.hooks // []) | map(select(.command != $cmd))))
      | .hooks[$event] |= map(select((.hooks | length) > 0))
      | (if (.hooks[$event] | length) == 0 then del(.hooks[$event]) else . end)
      | (if (.hooks | length) == 0 then del(.hooks) else . end)
    end' "$SETTINGS_FILE")
  write_settings "$result"
  echo "REMOVE  $event -> $cmd"
}

main() {
  local action=${1:-}
  if [[ "$action" != "add" && "$action" != "remove" ]]; then
    echo "Usage: $(basename "$0") add|remove" >&2
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR  jq is required (brew install jq)." >&2
    return 1
  fi
  ensure_settings_file
  local meta found=0
  for meta in "$SCRIPT_DIR"/*/hook.json; do
    [[ -f "$meta" ]] || continue
    found=1
    "${action}_hook" "$meta"
  done
  if [[ "$found" -eq 0 ]]; then
    echo "No hook.json found under $SCRIPT_DIR — nothing to do."
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
