# ==============================================================================
# REUSABLE RECIPES (MACROS)
# ==============================================================================

define init_venv
	@echo "🐍 Creating virtual environment..."
	@cd $(PROJECT_NAME) && uv venv
	@echo "🪄 Configuring direnv..."
	@cd $(PROJECT_NAME) && echo "source .venv/bin/activate" > .envrc && direnv allow
	@echo "📦 Installing base dependencies..."
	@cd $(PROJECT_NAME) && if [ -f requirements.txt ]; then uv pip install -r requirements.txt; else echo "No requirements.txt found, skipping."; fi
endef

# ==============================================================================
# PROJECT SETUP WORKFLOW
# ==============================================================================

copier_project: ## Scaffold a project with Copier (interactive picker: fnew)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with Copier..."
	@copier copy $(PROJECT_TEMPLATE_REPO) ./$(PROJECT_NAME)
	$(init_venv)
	@echo "✅ Project $(PROJECT_NAME) ready!"

CHECKOUT_ARG = $(if $(PROJECT_TEMPLATE_VERSION),--checkout $(PROJECT_TEMPLATE_VERSION),)

cruft_project: ## Scaffold a project with Cruft/Cookiecutter (interactive picker: fnew)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with Cruft..."
	@cruft create $(PROJECT_TEMPLATE_REPO) $(CHECKOUT_ARG) --extra-context '{"project_name": "$(PROJECT_NAME)", "repo_name": "$(PROJECT_NAME)"}'
	$(init_venv)
	@echo "✅ Project $(PROJECT_NAME) ready!"