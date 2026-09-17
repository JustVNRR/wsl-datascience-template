# ==============================================================================
# GLOBAL MAKEFILE & MLOPS WORKFLOW TARGETS
# ==============================================================================

# Dynamic path resolution: resolves the directory where THIS Makefile lives
THIS_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

# 1. Environment Variable Loading (Cascading Pattern)
# A. Load global fallback values relative to this file's location
-include $(THIS_DIR)/.env.global

# A-bis. Enforce the contract: .env.global holds shared defaults only. Variables
# that decide WHICH project a command targets are refused here — a stray one
# would silently retarget every gmake run made outside a project directory.
# (Command-line and environment values are not concerned.)
PROJECT_IDENTIFYING_VARS := GCP_PROJECT INSTANCE SA_NAME BUCKET_NAME BQ_DATASET TABLE_NAME GAR_IMAGE ARTIFACTSREPO SERVICE_URL
$(foreach var,$(PROJECT_IDENTIFYING_VARS),$(if $(filter file,$(origin $(var))),$(error ❌ ERROR: Variable $(var) identifies a project — it belongs in that project's .env, never in .env.global)))

# B. Load local project-specific overrides from the current working directory
# If .env exists locally, it overrides values from .env.global
-include .env

# B-bis. Whether a project .env was found here (drives the warnings in check_vars)
PROJECT_ENV := $(wildcard .env)

# 2. Export loaded variables to child subshells
export

# 3. Derive Service Account Email dynamically
SA_EMAIL = $(SA_NAME)@$(GCP_PROJECT).iam.gserviceaccount.com

# 4. Modular Sub-makefile Imports (loaded relative to this file)
include $(THIS_DIR)/make/*.mk

# --- Automatic Help Menu ---
.DEFAULT_GOAL := help

help: ## Show this help menu
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

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
