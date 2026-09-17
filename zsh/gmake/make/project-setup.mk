# ==============================================================================
# REUSABLE RECIPES (MACROS)
# ==============================================================================

# init_venv: detect the project's dependency manifest and bootstrap its environment.
# Exactly one branch installs dependencies:
#   1. uv.lock, or a PEP 621 [project] table  ->  uv sync (creates .venv,
#      installs dependencies + the dev group by default)
#   2. requirements.txt                        ->  uv venv + uv pip install
#      (+ requirements_dev.txt when present)
#   3. no recognized manifest                  ->  bare uv venv, with a warning
# The direnv hook is shared by all branches.
define init_venv
	@if [ -f $(PROJECT_NAME)/uv.lock ] || { [ -f $(PROJECT_NAME)/pyproject.toml ] && grep -qx '\[project\]' $(PROJECT_NAME)/pyproject.toml; }; then \
		echo "🐍 uv project detected (uv.lock or [project] table) — running uv sync..."; \
		cd $(PROJECT_NAME) && uv sync; \
	elif [ -f $(PROJECT_NAME)/requirements.txt ]; then \
		echo "🐍 Creating virtual environment..."; \
		cd $(PROJECT_NAME) && uv venv; \
		echo "📦 Installing dependencies (requirements.txt)..."; \
		uv pip install -r requirements.txt; \
		if [ -f requirements_dev.txt ]; then \
			echo "📦 Installing dev dependencies (requirements_dev.txt)..."; \
			uv pip install -r requirements_dev.txt; \
		fi; \
	else \
		echo "⚠️  No dependency manifest found (uv.lock / pyproject.toml [project] / requirements.txt)."; \
		echo "   Creating a bare venv — install your dependencies manually."; \
		cd $(PROJECT_NAME) && uv venv; \
	fi
	@echo "🪄 Configuring direnv..."
	@cd $(PROJECT_NAME) && echo "source .venv/bin/activate" > .envrc && direnv allow
endef

# ==============================================================================
# PROJECT SETUP WORKFLOW
# ==============================================================================

copier_project: ## Scaffold a project with Copier (interactive picker: fnew)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with Copier..."
	@copier copy $(COPIER_REF_ARG) $(PROJECT_TEMPLATE_REPO) ./$(PROJECT_NAME)
	$(init_venv)
	@echo "✅ Project $(PROJECT_NAME) ready!"

# Optional pinned template ref/tag: --vcs-ref for Copier, --checkout for Cruft
COPIER_REF_ARG = $(if $(PROJECT_TEMPLATE_VERSION),--vcs-ref $(PROJECT_TEMPLATE_VERSION),)
CHECKOUT_ARG = $(if $(PROJECT_TEMPLATE_VERSION),--checkout $(PROJECT_TEMPLATE_VERSION),)

cruft_project: ## Scaffold a project with Cruft/Cookiecutter (interactive picker: fnew)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with Cruft..."
	@cruft create $(PROJECT_TEMPLATE_REPO) $(CHECKOUT_ARG) --extra-context '{"project_name": "$(PROJECT_NAME)", "repo_name": "$(PROJECT_NAME)"}'
	$(init_venv)
	@echo "✅ Project $(PROJECT_NAME) ready!"