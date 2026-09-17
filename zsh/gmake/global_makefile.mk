# ==============================================================================
# GLOBAL MAKEFILE & MLOPS WORKFLOW TARGETS
# ==============================================================================

# Dynamic path resolution: resolves the directory where THIS Makefile lives
THIS_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

# 1. Environment Variable Loading (Cascading Pattern)
# A. Load global fallback values relative to this file's location
-include $(THIS_DIR)/.env.global

# B. Load local project-specific overrides from the current working directory
# If .env exists locally, it overrides values from .env.global
-include .env

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
define check_vars
	$(foreach var,$(1),$(if $(value $(var)),,$(error ❌ ERROR: Variable $(var) is required but unset)))
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
