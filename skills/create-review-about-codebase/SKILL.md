---
name: create-review-report-about-codebase
description: This skill might be used after using `ask-questions-about-codebase` and manual analysis of the `.data/codebase-questions-{YYYY-MM-DD-HH-MM}.md` file. The user is supposed to create the `my-notes.md` file at the same location as the `.data/codebase-questions-{YYYY-MM-DD-HH-MM}` file. This skill creates the final review report.
---

# Create review report about codebase

Read notes (`.data/my-notes.md` file) written manually by the user, and also the `.data/codebase-questions-{YYYY-MM-DD-HH-MM}.md` file (mostly for context).

## When to use this skill
Use this skill when the user needs to create a review report of the codebase.

## How to collect information?
1. Load the organization template located inside `review-template.md`
2. Substitute the template's simple variables:
  - {{CANDIDATE_NAME}}: ask the user for the candidate name if they don't provide it
  - {{REVIEW_DATE}}: the current date expressed in YYYY-MM-DD format

## Guidelines to generate the report

From the 2 loaded files, give a strong priority to user notes.

## How to output the results
1. Create a Markdown file called `.data/my-review.md`.
