#!/usr/bin/env bash
#
# neo-prepare-worktree — create one git worktree that can actually run the
# repository's own commands.
#
# `git worktree add` gives you the tracked files and nothing else: no ignored
# file, no untracked file, no installed dependency. Whatever a build, a test or
# a tool reads from those three categories has to be carried in or installed
# here, before an agent is dispatched into it.
#
# The copying happens in a script rather than in an agent's shell on purpose: a
# secret the agent is not allowed to read can still be carried, because nothing
# in the transfer passes through its context, and the copy is this one reviewed
# line rather than a command composed at runtime.
#
#   neo-prepare-worktree.sh --repo <main-checkout> --branch <branch> \
#                           --base <ref> --worktree <absolute-path> \
#                           [--carry <path-relative-to-repo>]... \
#                           [--install <command>]
#
# --carry is required-to-exist: a carry missing from the source is a broken
# plan, and it fails before the worktree is created rather than after.
# --install is run with the worktree as its working directory, through the
# shell, so it may carry flags and pipes.
#
# Prints a key=value summary on stdout. Exits 2 on a usage or setup error, or
# with the install command's status.

set -uo pipefail

PROGRAM=${0##*/}

die() {
  printf '%s: %s\n' "$PROGRAM" "$1" >&2
  exit 2
}

repo=''
branch=''
base=''
worktree=''
install_cmd=''
carries=''

while [ $# -gt 0 ]; do
  case $1 in
    --repo)     repo=${2:-};     shift 2 ;;
    --branch)   branch=${2:-};   shift 2 ;;
    --base)     base=${2:-};     shift 2 ;;
    --worktree) worktree=${2:-}; shift 2 ;;
    --carry)    carries="${carries}${2:-}"$'\n'; shift 2 ;;
    --install)  install_cmd=${2:-}; shift 2 ;;
    -h|--help)  sed -n '2,/^# Prints/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          die "unknown argument: $1" ;;
  esac
done

[ -n "$repo" ]     || die "--repo is required"
[ -n "$branch" ]   || die "--branch is required"
[ -n "$base" ]     || die "--base is required"
[ -n "$worktree" ] || die "--worktree is required"

repo=$(cd "$repo" 2>/dev/null && pwd -P) || die "no such directory: $repo"
git -C "$repo" rev-parse --show-toplevel >/dev/null 2>&1 || die "$repo is not a git checkout"

case $worktree in
  /*) ;;
  *) die "--worktree must be an absolute path: $worktree" ;;
esac

case $worktree in
  "$repo" | "$repo"/*)
    die "$worktree is inside $repo. A nested worktree is walked by the repository's own formatter, linter, test runner and packager, so every agent's gate would check every other agent's work. Put the worktrees beside the checkout."
    ;;
esac

[ -e "$worktree" ] && die "$worktree already exists — remove it or choose another path"

git -C "$repo" rev-parse --verify --quiet "$base" >/dev/null \
  || die "base ref not found: $base (run 'git -C $repo fetch origin' first)"

git -C "$repo" show-ref --verify --quiet "refs/heads/$branch" \
  && die "branch already exists: $branch"

# Validate every carry before anything is created, so a broken plan leaves no
# half-made worktree behind.
if [ -n "$carries" ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case $rel in
      /* | *..*) die "--carry takes a path relative to the checkout, with no '..': $rel" ;;
      .git | .git/*) die "--carry may not carry .git: $rel" ;;
    esac
    [ -e "$repo/$rel" ] || die "absent from $repo, so it cannot be carried: $rel"
  done <<EOF
$carries
EOF
fi

mkdir -p "$(dirname "$worktree")" || die "cannot create $(dirname "$worktree")"

git -C "$repo" worktree add --quiet -b "$branch" "$worktree" "$base" \
  || die "git worktree add failed for $branch at $worktree"

carried=''
sizes=''

if [ -n "$carries" ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    mkdir -p "$(dirname "$worktree/$rel")" || die "cannot create the parent of $rel"
    cp -R -p "$repo/$rel" "$worktree/$rel" || die "cannot carry $rel"
    carried="${carried}${rel},"
    if [ -d "$worktree/$rel" ]; then
      sizes="${sizes}${rel}=dir,"
    else
      sizes="${sizes}${rel}=$(wc -c < "$worktree/$rel" | tr -d ' '),"
    fi
  done <<EOF
$carries
EOF
fi

install_status=0
if [ -n "$install_cmd" ]; then
  ( cd "$worktree" && eval "$install_cmd" )
  install_status=$?
fi

printf 'worktree=%s\n' "$worktree"
printf 'branch=%s\n' "$branch"
printf 'base=%s\n' "$base"
printf 'head=%s\n' "$(git -C "$worktree" rev-parse --short HEAD)"
printf 'carried=%s\n' "${carried%,}"
printf 'carried_bytes=%s\n' "${sizes%,}"
printf 'install=%s\n' "${install_cmd:-none}"
printf 'install_status=%s\n' "$install_status"

exit "$install_status"
