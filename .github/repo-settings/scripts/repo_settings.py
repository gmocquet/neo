#!/usr/bin/env python3
"""Export and apply the GitHub repository configuration as code.

Source of truth: ``.github/repo-settings/settings.json`` — three sections:
``repository`` (subset of the REST "Update a repository" body), ``rulesets``
(createable ruleset bodies), and ``collaborators`` (outside collaborators).

All API access goes through the ``gh`` CLI, which must be authenticated (locally
via ``gh auth``, in CI via the ``GH_TOKEN`` env var holding a PAT with the
Administration permission — required to read/write rulesets).

Subcommands:
  export    Read the live repo and (over)write settings.json.
  validate  Validate settings.json against repo-settings.schema.json.
  diff      Show drift between settings.json and the live repo (exit 0).
  apply     Validate, then push settings.json to the repo via the API.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import jsonschema

ROOT = Path(__file__).resolve().parent.parent
SETTINGS = ROOT / "settings.json"
SCHEMA = ROOT / "repo-settings.schema.json"
DEFAULT_REPO = "gmocquet/neo"

# Managed keys of the "Update a repository" API body. Null-valued live keys are
# omitted from the export so apply never clears an unset field.
REPOSITORY_KEYS = [
    "description",
    "homepage",
    "default_branch",
    "visibility",
    "has_issues",
    "has_projects",
    "has_wiki",
    "has_discussions",
    "has_downloads",
    "is_template",
    "allow_forking",
    "web_commit_signoff_required",
    "allow_squash_merge",
    "allow_merge_commit",
    "allow_rebase_merge",
    "allow_auto_merge",
    "delete_branch_on_merge",
    "allow_update_branch",
    "squash_merge_commit_title",
    "squash_merge_commit_message",
    "merge_commit_title",
    "merge_commit_message",
]

# Server-generated ruleset fields dropped on export (not part of the createable body).
RULESET_SERVER_FIELDS = [
    "id",
    "node_id",
    "source",
    "source_type",
    "created_at",
    "updated_at",
    "_links",
    "current_user_can_bypass",
]
RULESET_BODY_FIELDS = ["name", "target", "enforcement", "conditions", "rules", "bypass_actors"]


def gh_api(path: str, method: str = "GET", body: dict | None = None) -> Any:
    """Call the GitHub API through `gh api` and return the parsed JSON (or None)."""
    cmd = ["gh", "api", "--method", method, path]
    if body is not None:
        cmd += ["--input", "-"]
    proc = subprocess.run(
        cmd,
        text=True,
        input=json.dumps(body) if body is not None else None,
        capture_output=True,
    )
    if proc.returncode:
        sys.exit(f"gh api {method} {path} failed:\n{proc.stderr.strip()}")
    out = proc.stdout.strip()
    return json.loads(out) if out else None


def owner_login(repo: str) -> str:
    return repo.split("/", 1)[0]


# --- read the live repository into the managed shape ------------------------


def live_repository(repo: str) -> dict:
    data = gh_api(f"repos/{repo}")
    return {k: data[k] for k in REPOSITORY_KEYS if data.get(k) is not None}


def strip_ruleset(ruleset: dict) -> dict:
    body = {k: ruleset[k] for k in RULESET_BODY_FIELDS if k in ruleset}
    conditions = body.get("conditions")
    if isinstance(conditions, dict):
        ref = conditions.get("ref_name")
        if isinstance(ref, dict):
            ref.setdefault("include", [])
            ref.setdefault("exclude", [])
    return body


def live_rulesets(repo: str) -> list[dict]:
    listed = gh_api(f"repos/{repo}/rulesets") or []
    rulesets = [gh_api(f"repos/{repo}/rulesets/{item['id']}") for item in listed]
    return [strip_ruleset(r) for r in sorted(rulesets, key=lambda r: r["name"])]


def live_collaborators(repo: str) -> list[dict]:
    owner = owner_login(repo)
    collaborators = gh_api(f"repos/{repo}/collaborators?affiliation=direct") or []
    return [
        {"username": c["login"], "permission": c["role_name"]}
        for c in sorted(collaborators, key=lambda c: c["login"])
        if c["login"] != owner
    ]


def live_settings(repo: str) -> dict:
    return {
        "repository": live_repository(repo),
        "rulesets": live_rulesets(repo),
        "collaborators": live_collaborators(repo),
    }


# --- config file & schema ---------------------------------------------------


def declared_settings() -> dict:
    data = json.loads(SETTINGS.read_text())
    data.pop("$schema", None)
    return data


def validate() -> None:
    instance = json.loads(SETTINGS.read_text())
    schema = json.loads(SCHEMA.read_text())
    try:
        jsonschema.validate(instance=instance, schema=schema)
    except jsonschema.ValidationError as exc:
        sys.exit(f"Schema validation failed: {exc.message}")
    print(f"{SETTINGS.name}: valid")


def write_settings(settings: dict) -> None:
    doc = {"$schema": "./repo-settings.schema.json", **settings}
    SETTINGS.write_text(json.dumps(doc, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


# --- subcommands ------------------------------------------------------------


def cmd_export(args: argparse.Namespace) -> int:
    settings = live_settings(args.repo)
    write_settings(settings)
    # Validate what we just wrote so a bad export fails loudly.
    validate()
    print(
        f"Exported {args.repo} to {SETTINGS.name}: "
        f"{len(settings['rulesets'])} ruleset(s), "
        f"{len(settings['collaborators'])} collaborator(s)."
    )
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    validate()
    return 0


def cmd_diff(args: argparse.Namespace) -> int:
    declared = declared_settings()
    live = live_settings(args.repo)
    drift = {
        section: (live.get(section), declared.get(section))
        for section in ("repository", "rulesets", "collaborators")
        if live.get(section) != declared.get(section)
    }
    if not drift:
        print(f"In sync: {args.repo} matches {SETTINGS.name}.")
        return 0
    print(f"Drift detected in {len(drift)} section(s) — repo vs {SETTINGS.name}:\n")
    for section, (live_value, declared_value) in drift.items():
        print(f"## {section}")
        print(f"  repo:   {json.dumps(live_value, sort_keys=True)}")
        print(f"  config: {json.dumps(declared_value, sort_keys=True)}\n")
    return args.check  # 0 unless --check


def apply_repository(repo: str, repository: dict) -> None:
    if repository:
        gh_api(f"repos/{repo}", method="PATCH", body=repository)
        print(f"  repository: patched {len(repository)} key(s).")


def apply_rulesets(repo: str, rulesets: list[dict]) -> None:
    existing = {r["name"]: r["id"] for r in (gh_api(f"repos/{repo}/rulesets") or [])}
    for ruleset in rulesets:
        name = ruleset["name"]
        if name in existing:
            gh_api(f"repos/{repo}/rulesets/{existing[name]}", method="PUT", body=ruleset)
            print(f"  ruleset '{name}': updated.")
        else:
            gh_api(f"repos/{repo}/rulesets", method="POST", body=ruleset)
            print(f"  ruleset '{name}': created.")


def apply_collaborators(repo: str, collaborators: list[dict], prune: bool) -> None:
    owner = owner_login(repo)
    for collaborator in collaborators:
        gh_api(
            f"repos/{repo}/collaborators/{collaborator['username']}",
            method="PUT",
            body={"permission": collaborator["permission"]},
        )
        print(f"  collaborator '{collaborator['username']}': ensured ({collaborator['permission']}).")
    if prune:
        declared = {c["username"] for c in collaborators}
        for existing in live_collaborators(repo):
            if existing["username"] not in declared and existing["username"] != owner:
                gh_api(f"repos/{repo}/collaborators/{existing['username']}", method="DELETE")
                print(f"  collaborator '{existing['username']}': removed (prune).")


def cmd_apply(args: argparse.Namespace) -> int:
    validate()
    declared = declared_settings()
    print(f"Applying {SETTINGS.name} to {args.repo}:")
    apply_repository(args.repo, declared.get("repository", {}))
    apply_rulesets(args.repo, declared.get("rulesets", []))
    apply_collaborators(args.repo, declared.get("collaborators", []), args.prune)
    print("Done.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--repo", default=DEFAULT_REPO, help=f"owner/repo to act on (default: {DEFAULT_REPO})"
    )

    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("export", parents=[common], help="read the live repo and write settings.json")
    sub.add_parser("validate", help="validate settings.json against the JSON Schema")
    diff_parser = sub.add_parser(
        "diff", parents=[common], help="show drift between settings.json and the live repo"
    )
    diff_parser.add_argument(
        "--check", action="store_true", help="exit non-zero if drift is found (for CI gating)"
    )
    apply_parser = sub.add_parser(
        "apply", parents=[common], help="validate, then push settings.json to the repo"
    )
    apply_parser.add_argument(
        "--prune",
        action="store_true",
        help="also remove outside collaborators not declared in settings.json",
    )

    args = parser.parse_args(argv)
    handlers = {
        "export": cmd_export,
        "validate": cmd_validate,
        "diff": cmd_diff,
        "apply": cmd_apply,
    }
    return handlers[args.command](args)


if __name__ == "__main__":
    raise SystemExit(main())
