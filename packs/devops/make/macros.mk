# ==============================================================================
# WHAT A TARGET SAYS BEFORE IT RUNS
# ==============================================================================
# Two macros, and every module that writes a target uses them: one refuses to
# run when a variable it needs is unset, the other prints what the target is
# about to touch and waits for a yes.
#
# They live in this pack because they are the project targets' manners - the
# socle has no target of its own that needs either. A pack whose targets call
# them depends on `devops`, and says so in its pack.conf: an undefined macro
# expands to nothing, so a missing `devops` would not fail, it would quietly drop
# the check and run.
#
# They are defined, never run here: everything below is expanded at the moment
# a recipe calls it, so the module can be loaded in any order relative to the
# targets that use it.

# Macro 1: Assert required variables are non-empty (Fail-fast validation)
# When no project .env was found, the error says so — and when the values in
# effect come from neither a project .env nor the command line (i.e. only from
# .env.global or the environment), a warning is printed before the recipe runs.
define check_vars
	$(foreach var,$(1),$(if $(value $(var)),,$(error ❌ ERROR: Variable $(var) is required but unset$(if $(PROJECT_ENV),, (no .env in this directory — only .env.global is loaded)))))
	@if [ -z "$(PROJECT_ENV)" ] && [ -z "$(strip $(foreach var,$(1),$(if $(filter command line,$(origin $(var))),x)))" ]; then \
		echo "⚠️  No .env in this directory — values in effect come from .env.global or the environment only."; \
	fi
endef

# Macro 2: Print target variables and prompt for operator confirmation
define confirm_action
	@echo "\n======================================================="
	@echo " ⚠️  TARGET ACTION: $(1)"
	@echo "======================================================="
	@$(foreach var,$(2),echo " 🔹 $(var) : \033[33m$($(var))\033[0m";)
	@echo "======================================================="
	@read -p "Confirm execution? [y/N] " ans; \
	if [ "$$ans" != "y" ] && [ "$$ans" != "Y" ]; then echo "\n❌ Operation cancelled by user." >&2; exit 1; fi
	@echo "✅ Operation confirmed.\n"
endef
