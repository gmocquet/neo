# neo — install helpers
#
# Skills are installed by symlinking each skills/<name> directory into the
# user-level skills directory of the coding agent (~/.claude/skills for
# Claude Code). Symlinks keep the install in sync with this repo: `git pull`
# updates every linked skill in place.

CLAUDE_SKILLS_DIR ?= $(HOME)/.claude/skills
SKILLS_SRC_DIR    := $(CURDIR)/skills

.DEFAULT_GOAL := help
.PHONY: help skills-link skills-unlink hooks-add hooks-remove

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-24s %s\n", $$1, $$2}'

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
