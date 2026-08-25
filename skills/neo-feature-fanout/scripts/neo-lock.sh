#!/usr/bin/env bash
#
# neo-lock — serialise a command across git worktrees, without flock(1).
#
# macOS ships no flock binary, and a lock file created with a shell redirect is
# not atomic: two shells can both believe they created it. `mkdir` is atomic on
# every POSIX filesystem, APFS included, so the lock here is the directory
# itself.
#
# The lock directory is shared by every worktree of one repository. It lives
# beside the checkout, never inside it, so holding a lock never dirties a
# working tree and never needs a commit to the repository under test.
#
#   neo-lock.sh <lock-directory> [--] <command> [args...]
#
# Environment:
#   NEO_LOCK_TIMEOUT  seconds to wait before giving up            (default 3600)
#   NEO_LOCK_STALE    seconds after which a dead owner's lock
#                     may be broken                               (default 1800)
#   NEO_LOCK_POLL     seconds between attempts                    (default 5)
#
# Exit status: the wrapped command's, 2 on a usage error, or 75 (EX_TEMPFAIL)
# when the lock never came free.

set -uo pipefail

PROGRAM=${0##*/}

die() {
  printf '%s: %s\n' "$PROGRAM" "$1" >&2
  exit 2
}

if [ $# -lt 2 ]; then
  die "usage: $PROGRAM <lock-directory> [--] <command> [args...]"
fi

lock_dir=$1
shift
if [ "${1:-}" = "--" ]; then shift; fi
[ $# -ge 1 ] || die "no command to run"

case $lock_dir in
  /*) ;;
  *) die "the lock directory must be an absolute path: $lock_dir" ;;
esac

timeout=${NEO_LOCK_TIMEOUT:-3600}
stale=${NEO_LOCK_STALE:-1800}
poll=${NEO_LOCK_POLL:-5}

owner_file=$lock_dir/owner
host=$(hostname 2>/dev/null || echo unknown)
token="$$-$(date +%s)-${RANDOM}"

mkdir -p "$(dirname "$lock_dir")" || die "cannot create $(dirname "$lock_dir")"

# BSD and GNU stat disagree on every flag that matters here.
mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Only ever remove a lock we still hold. If ours went stale and somebody broke
# it, the directory now belongs to them and must not be touched.
release() {
  if [ -f "$owner_file" ] && grep -qxF "token=$token" "$owner_file" 2>/dev/null; then
    rm -rf "$lock_dir"
  fi
}

trap 'release' EXIT
trap 'release; exit 130' INT
trap 'release; exit 143' TERM

break_if_stale() {
  local since owner_host owner_pid age

  if [ -f "$owner_file" ]; then
    since=$(sed -n 's/^epoch=//p' "$owner_file" 2>/dev/null)
    owner_host=$(sed -n 's/^host=//p' "$owner_file" 2>/dev/null)
    owner_pid=$(sed -n 's/^pid=//p' "$owner_file" 2>/dev/null)
  else
    # Created but not yet stamped — normally a millisecond. Falling back to the
    # directory's own mtime means a process killed inside that window does not
    # leave a lock nobody can ever break.
    since=$(mtime "$lock_dir")
    owner_host=''
    owner_pid=''
  fi

  case $since in
    '' | *[!0-9]*) return 1 ;;
  esac

  age=$(( $(date +%s) - since ))
  [ "$age" -ge "$stale" ] || return 1

  # Age alone is not enough: a long end-to-end run is not a crash. On this host
  # a live pid means the holder is still working.
  if [ "$owner_host" = "$host" ] && [ -n "$owner_pid" ] && kill -0 "$owner_pid" 2>/dev/null; then
    return 1
  fi

  # mv is atomic within a filesystem, so exactly one of several waiters wins the
  # break; the losers find the directory gone and go back to mkdir.
  if mv "$lock_dir" "$lock_dir.stale.$$" 2>/dev/null; then
    printf '%s: broke a stale lock, held %ss by pid %s on %s\n' \
      "$PROGRAM" "$age" "${owner_pid:-?}" "${owner_host:-?}" >&2
    rm -rf "$lock_dir.stale.$$"
  fi

  return 0
}

waited=0
announced=0

while ! mkdir "$lock_dir" 2>/dev/null; do
  if break_if_stale; then
    continue
  fi

  if [ "$waited" -ge "$timeout" ]; then
    printf '%s: gave up after %ss waiting for %s\n' "$PROGRAM" "$waited" "$lock_dir" >&2
    sed 's/^/  /' "$owner_file" 2>/dev/null >&2
    exit 75
  fi

  if [ "$announced" -eq 0 ]; then
    printf '%s: waiting for %s\n' "$PROGRAM" "$lock_dir" >&2
    announced=1
  fi

  sleep "$poll"
  waited=$(( waited + poll ))
done

{
  printf 'token=%s\n' "$token"
  printf 'pid=%s\n' "$$"
  printf 'host=%s\n' "$host"
  printf 'epoch=%s\n' "$(date +%s)"
  printf 'started=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf 'cwd=%s\n' "$PWD"
  printf 'command=%s\n' "$*"
} > "$owner_file"

"$@"
exit $?
