# ==============================================================================
# WHAT A TARGET SAYS BEFORE IT RUNS
# ==============================================================================
# Two macros, and every module that writes a target uses them: one refuses to
# run when a variable it needs is unset, the other prints what the target is
# about to touch and waits for a yes.
#
# They are the socle's, and they are here rather than in a pack because they are
# not a service a pack renders - they are how a target is written, the way the
# location gate in the Makefile says where a target may run. A pack that writes
# a target uses them and declares nothing. (merge_env_samples is the third
# macro, and it is a pack's: it assembles the .env files, and the dev pack is
# the only thing that assembles them.)
#
# A PACK MUST NEVER DEFINE EITHER. The socle's modules are read first and the
# packs' after, so a pack's own `define check_vars` would win in silence and
# every target that calls it - the pack's, and its neighbours' - would lose its
# check. That is what the CI greps for on every push: a comment cannot notice.
#
# They are defined, never run here: everything below is expanded at the moment
# a recipe calls it, so a module can be loaded in any order relative to the
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
