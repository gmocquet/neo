# neo — install helpers
#
# Skills are installed by symlinking each skills/<name> directory into the
# user-level skills directory of the coding agent (~/.claude/skills for
# Claude Code). Symlinks keep the install in sync with this repo: `git pull`
# updates every linked skill in place.

CLAUDE_SKILLS_DIR ?= $(HOME)/.claude/skills
SKILLS_SRC_DIR    := $(CURDIR)/skills

REPO       ?= gmocquet/neo
REPO_SETTINGS := uv run --project $(CURDIR)/.github/repo-settings $(CURDIR)/.github/repo-settings/scripts/repo_settings.py
REPO_SETTINGS_SECRET := REPO_SETTINGS_TOKEN
REPO_OWNER := $(firstword $(subst /, ,$(REPO)))
REPO_NAME  := $(notdir $(REPO))
# Pre-fills the fine-grained PAT form (name, description, no expiration, resource
# owner, Administration: Read and write). Repository selection has no URL
# parameter, so the user still picks the repo manually. The description reads:
# "CI token for the neo repository, the central versioned home for AI coding-agent
#  assets such as skills and hooks. Used by the repo-settings GitHub Actions
#  workflow to apply the repository configuration (settings, rulesets, and access)
#  as code. Scope: Administration read and write on neo only."
REPO_SETTINGS_TOKEN_DESC := CI%20token%20for%20the%20neo%20repository%2C%20the%20central%20versioned%20home%20for%20AI%20coding-agent%20assets%20such%20as%20skills%20and%20hooks.%20Used%20by%20the%20repo-settings%20GitHub%20Actions%20workflow%20to%20apply%20the%20repository%20configuration%20%28settings%2C%20rulesets%2C%20and%20access%29%20as%20code.%20Scope%3A%20Administration%20read%20and%20write%20on%20neo%20only.
REPO_SETTINGS_TOKEN_NAME := ci-repo-settings-$(REPO_NAME)
REPO_SETTINGS_TOKEN_URL := https://github.com/settings/personal-access-tokens/new?name=$(REPO_SETTINGS_TOKEN_NAME)&description=$(REPO_SETTINGS_TOKEN_DESC)&target_name=$(REPO_OWNER)&expires_in=none&administration=write

.DEFAULT_GOAL := help
.PHONY: help init sync-add sync-remove skills-link skills-unlink hooks-add hooks-remove pre-commit-install repo-settings-export repo-settings-validate repo-settings-diff repo-settings-apply repo-settings-token-set repo-settings-token-status repo-settings-token-delete

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-24s %s\n", $$1, $$2}'

init: ## Set up the local dev environment (uv sync + git hooks) — run once after cloning
	@command -v uv >/dev/null 2>&1 || { echo "uv not found — install it first (e.g. brew install uv)"; exit 1; }
	@uv sync
	@$(MAKE) --no-print-directory pre-commit-install

sync-add: skills-link hooks-add ## Install every AI asset at the user level (skills + hooks); repo-settings excluded
	@echo "sync-add: skills linked and hooks registered."

sync-remove: skills-unlink hooks-remove ## Remove every AI asset installed by sync-add (skills + hooks)
	@echo "sync-remove: skills unlinked and hooks unregistered."

skills-link: ## Symlink every skill into $(CLAUDE_SKILLS_DIR)
	@mkdir -p "$(CLAUDE_SKILLS_DIR)"
	@for src in "$(SKILLS_SRC_DIR)"/*/; do \
		src="$${src%/}"; \
		skill=$$(basename "$$src"); \
		dst="$(CLAUDE_SKILLS_DIR)/$$skill"; \
		if [ ! -f "$$src/SKILL.md" ]; then \
			echo "SKIP  $$skill (no SKILL.md)"; \
		elif [ -e "$$dst" ] && [ ! -L "$$dst" ]; then \
			echo "SKIP  $$skill — $$dst already exists and is not a symlink (resolve manually)"; \
		else \
			ln -sfn "$$src" "$$dst"; \
			echo "LINK  $$dst -> $$src"; \
		fi; \
	done

skills-unlink: ## Remove the skill symlinks installed by `make skills-link`
	@for src in "$(SKILLS_SRC_DIR)"/*/; do \
		src="$${src%/}"; \
		skill=$$(basename "$$src"); \
		dst="$(CLAUDE_SKILLS_DIR)/$$skill"; \
		if [ -L "$$dst" ] && [ "$$(readlink "$$dst")" = "$$src" ]; then \
			rm "$$dst"; \
			echo "UNLINK  $$dst"; \
		elif [ -e "$$dst" ]; then \
			echo "SKIP  $$skill — $$dst was not installed from this repository"; \
		fi; \
	done

hooks-add: ## Register this repo's hooks in the user's Claude Code settings (jq merge, existing config preserved)
	@"$(CURDIR)/hooks/hooks-config.sh" add

hooks-remove: ## Unregister this repo's hooks from the user's Claude Code settings (other hooks and keys preserved)
	@"$(CURDIR)/hooks/hooks-config.sh" remove

pre-commit-install: ## Install the pre-commit, commit-msg, and pre-push git hooks using the project's pinned pre-commit
	@command -v uv >/dev/null 2>&1 || { echo "uv not found — install it first (e.g. brew install uv)"; exit 1; }
	@uv run pre-commit install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push

repo-settings-export: ## Export the live repo config into .github/repo-settings/repo-settings.json (manual)
	@$(REPO_SETTINGS) export --repo $(REPO)

repo-settings-validate: ## Validate repo-settings.json against the JSON Schema
	@$(REPO_SETTINGS) validate

repo-settings-diff: ## Show drift between repo-settings.json and the live repo config (check before pushing)
	@$(REPO_SETTINGS) diff --repo $(REPO)

repo-settings-apply: ## Apply repo-settings.json to the repo config via the API
	@$(REPO_SETTINGS) apply --repo $(REPO)

repo-settings-token-set: ## Create the CI PAT (pre-filled page), verify it can administer the repo, and store it as REPO_SETTINGS_TOKEN
	@echo "About this token: it lets the CI apply $(REPO_NAME)'s GitHub configuration"
	@echo "(settings, rulesets, access) as code. $(REPO_NAME) = central versioned home for"
	@echo "AI coding-agent assets (skills, hooks). Scope: Administration read/write on $(REPO_NAME)."
	@echo ""
	@echo "Opening the pre-filled PAT page (name, description, no expiration, and"
	@echo "Administration: Read and write are already set). You only need to:"
	@echo "  - set Repository access -> Only select repositories -> $(REPO)"
	@echo "    (GitHub has no URL parameter to pre-select the repository)"
	@echo "  - click Generate token, then copy it."
	@echo ""
	@if command -v open >/dev/null 2>&1; then open "$(REPO_SETTINGS_TOKEN_URL)"; \
		elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$(REPO_SETTINGS_TOKEN_URL)"; \
		else echo "Open this URL: $(REPO_SETTINGS_TOKEN_URL)"; fi
	@printf "Paste the token, then press Enter: "; \
		stty -echo 2>/dev/null; read -r token; stty echo 2>/dev/null; echo; \
		[ -n "$$token" ] || { echo "no token entered — aborting." >&2; exit 1; }; \
		echo "==> verifying the token can administer $(REPO) (no-op settings write)..."; \
		issues=$$(GH_TOKEN="$$token" gh api "repos/$(REPO)" -q '.has_issues' 2>/dev/null) || { echo "ERROR: token cannot read $(REPO) — wrong repository selected? NOT stored." >&2; exit 1; }; \
		GH_TOKEN="$$token" gh api -X PATCH "repos/$(REPO)" -F "has_issues=$$issues" >/dev/null 2>&1 || { echo "ERROR: token lacks Administration write on $(REPO) — NOT stored." >&2; echo "  Fix the PAT: Resource owner -> $(REPO_OWNER); Repository access -> Only select repositories -> $(REPO); Administration: Read and write." >&2; exit 1; }; \
		printf '%s' "$$token" | gh secret set $(REPO_SETTINGS_SECRET) --repo $(REPO) \
		&& echo "==> $(REPO_SETTINGS_SECRET) stored and verified on $(REPO)."
	@echo ""
	@echo "Secret stored on $(REPO). Next steps:"
	@echo "  1. Check it:          make repo-settings-token-status"
	@echo "  2. Preview the drift:  make repo-settings-diff"
	@echo "  3. Re-run the red 'repo-settings' CI check on your PR (or push again) — it passes now."
	@echo "  4. Merge the PR; on the main branch the CI applies repo-settings.json to the repo."

repo-settings-token-status: ## Report whether the REPO_SETTINGS_TOKEN Actions secret exists
	@gh secret list --repo $(REPO) | grep -q '^$(REPO_SETTINGS_SECRET)[[:space:]]' \
		&& echo "$(REPO_SETTINGS_SECRET): set on $(REPO)" \
		|| echo "$(REPO_SETTINGS_SECRET): not set on $(REPO)"

repo-settings-token-delete: ## Delete the REPO_SETTINGS_TOKEN Actions secret and open the tokens page to revoke the PAT
	@if gh secret delete $(REPO_SETTINGS_SECRET) --repo $(REPO) 2>/dev/null; then \
		echo "==> deleted the $(REPO_SETTINGS_SECRET) Actions secret from $(REPO)"; \
	else \
		echo "==> $(REPO_SETTINGS_SECRET) Actions secret not found on $(REPO) (already removed?)"; \
	fi
	@echo ""
	@echo "GitHub has no API to delete a personal access token — revoke it in the browser:"
	@echo "  find the fine-grained token named '$(REPO_SETTINGS_TOKEN_NAME)' (or whichever you created), open it, and Delete."
	@echo "  https://github.com/settings/personal-access-tokens"
	@if command -v open >/dev/null 2>&1; then open "https://github.com/settings/personal-access-tokens"; \
		elif command -v xdg-open >/dev/null 2>&1; then xdg-open "https://github.com/settings/personal-access-tokens"; \
		else echo "Open this URL: https://github.com/settings/personal-access-tokens"; fi
