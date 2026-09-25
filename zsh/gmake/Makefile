# ==============================================================================
# THE GMAKE MAKEFILE & MLOPS WORKFLOW TARGETS
# ==============================================================================

# Dynamic path resolution: resolves the directory where THIS Makefile lives
THIS_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

# The packs: one level above this file's own directory. That is the same path
# in both places — `packs/`, next to `zsh/`, in the repository, and
# `~/.config/packs`, next to `~/.config/zsh`, in the instance.
# Named here, at the top, because A-bis reads a pack's declaration before it
# may load anything of one, and section 5 globs the modules from here.
PACKS_DIR := $(abspath $(THIS_DIR)/../../packs)

# 1. Environment Variable Loading (Cascading Pattern)
# A. Load global fallback values relative to this file's location
-include $(THIS_DIR)/.env.global

# A-bis. Enforce the contract: .env.global holds shared defaults only. Variables
# that decide WHICH project a command targets are refused here — a stray one
# would silently retarget every gmake run made outside a project directory.
# (Command-line and environment values are not concerned.)
#
# The socle names its own; a pack declares its share in its pack.conf. That
# file is read here with sed rather than included, for one reason: this check
# runs while .env.global is being loaded, before any pack is allowed to define
# anything. No comment line survives the sed, so the declaration is not
# mistaken for prose.
SOCLE_IDENTIFYING_VARS := DOCKER_LOCAL_IMAGE
PACK_IDENTIFYING_VARS := $(shell sed -n 's/^PACK_IDENTIFYING_VARS *:=[[:space:]]*//p' $(PACKS_DIR)/*/pack.conf 2>/dev/null)
PROJECT_IDENTIFYING_VARS := $(SOCLE_IDENTIFYING_VARS) $(PACK_IDENTIFYING_VARS)
$(foreach var,$(PROJECT_IDENTIFYING_VARS),$(if $(filter file,$(origin $(var))),$(error ❌ ERROR: Variable $(var) identifies a project — it belongs in that project's .env, never in .env.global)))

# B. Load local project-specific overrides from the current working directory
# If .env exists locally, it overrides values from .env.global
-include .env

# B-bis. Whether a project .env was found here (drives the warnings in check_vars)
PROJECT_ENV := $(wildcard .env)

# 2. Export loaded variables to child subshells
export

# 3. Derived variables
# A variable derived from a project's identity belongs to the pack that reads
# it: SA_EMAIL is in packs/gcp/make/gcp.mk, where its reader lives. Nothing is
# derived here.

# 4. Modular Sub-makefile Imports (loaded relative to this file)
#
# Two globs, no name in either: make/*.mk is the socle's own modules, and
# packs/*/make/*.mk is every installed pack's. Adding a module, or a whole
# pack, is creating a file or a directory - nothing to edit here.
#
# `gmake help` is built by reading the *text* of the files make loaded, not
# from the targets make defined. A module that was not loaded contributes no
# line at all: that is what makes the menu follow the machine - and what
# decides is now nothing but the folder being there. A pack is installed when
# its folder is in ~/.config/packs, which is where `.\wsl.ps1 add_pack` puts
# it, files and tool together. There is no binary to test and no variable to
# force, so the menu cannot show a pack's commands and mean something else -
# unlike the two-faced arrangement it replaces, where a machine that happened
# to ship the CLI decided what everyone read.
CORE_MODULES := $(wildcard $(THIS_DIR)/make/*.mk)
PACK_MODULES := $(wildcard $(PACKS_DIR)/*/make/*.mk)

include $(CORE_MODULES)
include $(PACK_MODULES)

# 5. Location gate: where gmake targets are allowed to run.
#   - operational targets: from the root of a project (a direct child of ~/projects)
#   - scaffolding targets: from ~/projects itself
#   - onboarding and install targets, and help: from anywhere
# GMAKE_ANYWHERE=1 bypasses the gate for tests or unconventional setups.
#
# Read LAST, after every module, and that placement is the whole point: `$(error)`
# fires when make READS the line, so a gate checked before the includes could not
# know what a pack declares. The scaffolding goals are named by the pack that
# defines them - SCAFFOLD_GOALS, in its own module - and the socle names no
# target of a pack any more. A target nobody declares is treated as an ordinary
# project target, which is the right answer for the socle's own.
#
# packs_list is exempt for the same reason help is: it reads the machine, not a
# project, and the question "what do I have?" is asked from wherever you stand.
GATE_EXEMPT_GOALS := help env_global_enable packs_list
ifneq (,$(filter $(SCAFFOLD_GOALS),$(MAKECMDGOALS)))
ifeq (,$(GMAKE_ANYWHERE))
ifneq ($(HOME)/projects,$(CURDIR))
$(error ❌ ERROR: Scaffolding runs from ~/projects itself (current directory: $(CURDIR)) — set GMAKE_ANYWHERE=1 to bypass)
endif
endif
endif
ifneq (,$(filter-out $(GATE_EXEMPT_GOALS) $(SCAFFOLD_GOALS),$(MAKECMDGOALS)))
ifeq (,$(GMAKE_ANYWHERE))
ifneq ($(HOME)/projects,$(patsubst %/,%,$(dir $(CURDIR))))
$(error ❌ ERROR: gmake targets run from the root of a project under ~/projects (current directory: $(CURDIR)) — set GMAKE_ANYWHERE=1 to bypass)
endif
endif
endif

# --- Automatic Help Menu ---
.DEFAULT_GOAL := help

# Sorted by target name rather than by the order the modules were read: a
# command is where its name says it is, whichever file defines it. The families
# stay together anyway - gcp_*, gcs_*, vm_*, bigquery_*, cloudrun_* share their
# prefix - and a target only appears when the tool behind it is installed, so
# its neighbours are the ones it actually belongs with.
help: ## Show this help menu
	@awk 'BEGIN { printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n" }'
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) | sort -f

# ==============================================================================
# DYNAMIC SAFETY MACROS
# ==============================================================================

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

# Macro 3: create or complete an environment file from the samples, in order.
# The socle's sample comes first, the packs' follow - each carries its own
# header, so the assembled file documents itself.
# Nothing is ever *rewritten*: a variable the target already defines is left
# alone, which is what makes the two commands safe to re-run. A value you
# filled in survives, and so does a pack you add later.
#   $(1) the file to write   $(2) the samples to read
define merge_env_samples
	@target=$(1); \
	samples="$(2)"; \
	if [ ! -f "$$target" ]; then \
		echo "📝 Creating $$target from the samples..."; \
		: > "$$target"; \
		for s in $$samples; do [ -f "$$s" ] && cat "$$s" >> "$$target"; done; \
		echo "✏️  Fill in the values you need — each block documents its own."; \
	else \
		added=0; \
		for s in $$samples; do \
			[ -f "$$s" ] || continue; \
			missing=$$(awk -F= 'FNR==NR { if ($$0 ~ /^[A-Za-z_][A-Za-z0-9_]*=/) seen[$$1]=1; next } $$0 ~ /^[A-Za-z_][A-Za-z0-9_]*=/ && !($$1 in seen)' "$$target" "$$s"); \
			[ -z "$$missing" ] && continue; \
			if [ $$added -eq 0 ]; then \
				printf '\n# --- gmake variables added from the samples ---\n' >> "$$target"; \
				added=1; \
			fi; \
			printf '%s\n' "$$missing" >> "$$target"; \
		done; \
		if [ $$added -eq 0 ]; then \
			echo "ℹ️  $$target already defines every gmake variable — nothing to add."; \
		else \
			echo "📝 Added the missing variables to $$target."; \
		fi; \
	fi
endef
