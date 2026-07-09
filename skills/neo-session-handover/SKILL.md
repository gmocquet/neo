---
name: neo-session-handover
description: Compact the current conversation into a cleaned, full-fidelity context snapshot another agent can pick up. Strips noise (logs, intermediate steps, irrelevant input) without losing any goal-relevant information.
argument-hint: "Which remaining steps should the next session focus on?"
disable-model-invocation: true
---

# Handover: cleaned context snapshot

Produce a document that lets a fresh agent continue this work with **zero loss of goal-relevant information**.

This is **not a summary**. It is the full, current context with the noise removed. Do not abstract, paraphrase, generalise, or shorten the substance. Keep the actual content; only strip what carries no signal for the goal. When in doubt about whether something is signal or noise, keep it.

Save the document to `./tmp/contexte/` in the current project (create the directory if it does not exist). Name the file with the generation date, e.g. `handover-2026-06-22-1545.md`.

## Header metadata (captured at dump time)

As your first action, before writing anything, run the single command below with the Bash tool to capture the real header values, then parse its `key=value` output into the header block. Do not fill these fields from memory, and do not guess. The command is tuned for macOS with Linux fallbacks; any field that comes back empty must be written as `unknown`.

    { echo "generated=$(date "+%Y-%m-%dT%H:%M:%S%z")"; echo "user=$(whoami)"; if command -v sw_vers >/dev/null 2>&1; then echo "os=$(sw_vers -productName) $(sw_vers -productVersion)"; else echo "os=$(uname -sr)"; fi; echo "claude_code=$(claude --version 2>/dev/null || echo unknown)"; f=$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1); if [ -n "$f" ]; then echo "session_id=$(basename "$f" .jsonl)"; echo "session_size=$(ls -lh "$f" | awk '{print $5}')"; echo "session_start=$(stat -f '%SB' -t '%Y-%m-%dT%H:%M:%S%z' "$f" 2>/dev/null || stat -c '%w' "$f" 2>/dev/null || echo unknown)"; echo "last_action=$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S%z' "$f" 2>/dev/null || stat -c '%y' "$f" 2>/dev/null || echo unknown)"; else echo "session_id=unknown"; echo "session_size=unknown"; echo "session_start=unknown"; echo "last_action=$(date "+%Y-%m-%dT%H:%M:%S%z")"; fi; }

Map the output keys to header fields: generated to `Generated`, user to `User`, os to `OS`, claude_code to `Claude Code`, session_id to `Session ID`, session_size to `Session size`, session_start to `Session start`, last_action to `Last action`.

These three cannot be read from the shell. Fill them as best you can, using `unknown` rather than guessing:
- `Model`: the model you are currently running as, or `unknown`.
- `Effort`: `unknown` unless you can otherwise determine it.
- `Reasoning`: `on` or `off` if you can determine it; otherwise `unknown`.

## Required structure (every section always present, always filled in)

The document must contain these sections, in this order. None may be omitted. If a section genuinely has no content, write `None` under it rather than removing the heading.

1. **Header.** Start with `# Handover: <short goal title>`, then one metadata field per line, in this order, built from the values captured above (write `unknown` for anything unresolved). Include the `Next steps focus` line only when a focus was provided. Layout:

        # Handover: <short goal title>

        Generated:        2026-06-22T15:45:08+0200
        User:             gmocquet
        OS:               macOS 26.5.1
        Claude Code:      2.1.34
        Model:            Opus 4.8
        Effort:           xhigh
        Reasoning:        on
        Session ID:       67614647-7351-408e-88b8-2846dc62b860
        Session size:     1.2M
        Session start:    2026-06-22T09:12:33+0200
        Last action:      2026-06-22T15:45:08+0200
        Next steps focus: <focus, or omit this line if none>

2. `## Goal`: the overall objective of the session in plain terms (the feature to build, the refactor to carry out, the bug to fix, and so on). One short paragraph.
3. `## Plan / roadmap`: the roadmap as currently understood, plus references to the tracking artifacts (JIRA tickets, GitHub issues, PRs, milestones, Projects). Reference each by ID and URL, do not copy their content.
4. `## Completed steps`: every step already done, each on its own line with an explicit status of `success`, `skipped`, or `blocked`, plus a few words on the outcome where it matters.
5. `## Current steps`: the most recent action, the one in flight or just finished at dump time, and where it stands. State the action, then its status, drawn from `in-progress`, `done (unverified)`, `blocked`, or `failing`, then the concrete evidence the status rests on (last command output or exit status, test result, file or git state, PR or CI state). Derive the status only from information you can actually retrieve; if you cannot determine it, write `unknown` and name what would need to be checked to confirm it. If nothing was in flight and the last action completed cleanly, write `None`.
6. `## Next steps`: what remains to do, ordered by what should happen first. Concrete enough that the next agent can act without re-deriving the plan. If a `Next steps focus` was provided, order these so the focused steps come first.
7. `## Key context & decisions`: all the goal-relevant substance that does not fit the sections above (decisions taken and why, constraints, design choices, final results of iterations, and the useful excerpts extracted from input documents). The keep/drop rules below apply here.
8. `## Suggested skills`: the skills the next agent should invoke to continue, each with a one-line reason.
9. `## Suggested CLIs`: the command-line tools this session relied on that the next agent will need. For each: the tool name, what it is used for, and an auth status, which is one of `ready` (already authenticated, e.g. via OAuth or SSO; note where the credential lives, such as a config path or env var, so the next agent can find it), `needs auth` (give the exact step to authenticate: the login command to run, or the env var to set and where to obtain its value), or `unknown` (state you could not confirm the status, and give the command to check it, e.g. `gh auth status`, `aws sts get-caller-identity`). Never write an actual token, key, or password into the document; describe how to obtain or set it, not the value itself.
10. `## Suggested MCPs`: the MCP servers this session used or will need, same treatment. For each: the server name, what it provides, and a connection status, which is one of `ready` (connected and usable, e.g. authenticated via OAuth in the host), `needs setup` (give how to connect it: the config entry or `claude mcp add` command, and which credential to provide), or `unknown` (say so, and how to verify). As with CLIs, never paste secrets into the document, reference how to obtain or set them.

## Keep (verbatim, full fidelity)
- For any data I gave you, keep only its latest, most up-to-date version. Deduplicate: if a value, decision, or piece of content was revised during the conversation, keep the final version and discard the superseded ones.
- For an iterative exchange (several back-and-forths converging on something), keep only the final result. Discard the intermediate inputs and outputs that led to it.
- For an input document (e.g. a 10-page PDF where only one or two paragraphs matter), extract and keep only the passages actually useful for the goal. Ignore the rest of the document.

## Drop (noise)
- CLI logs, command output, tool results, stack traces, and any other transient output (keep the distilled outcome, not the raw log).
- Intermediate iterations once a final result supersedes them.
- Side problems unrelated to the main goal (e.g. a GitHub account not linked, an environment or setup hiccup, an auth glitch). If it was not part of solving the actual task, leave it out entirely.

## Don't duplicate existing artifacts
If information already lives in another artifact (PRD, plan, ADR, issue, commit, diff, doc, and so on), do not copy it into the handover. Reference it by file path or URL instead.

## Focus
$ARGUMENTS

If the line above is non-empty, treat it as which of the next steps the next session should focus on. Record it as the `Next steps focus` line in the header, foreground the context relevant to those steps, order the Next steps so the focused ones come first, and you may drop context clearly irrelevant to them.
