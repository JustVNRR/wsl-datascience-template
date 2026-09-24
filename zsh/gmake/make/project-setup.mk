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
# The direnv hook is shared by all branches, and it writes over nothing that is
# already there: our own template ships an .envrc that also loads .env through
# dotenv, and another template's .envrc is its own business. Ours is written
# only where there is none - with the guard that keeps it quiet before the
# first `uv sync` - and then approved, so the project is usable on the way in.
#
# The same rule for the project's .env: the sample the template ships is copied
# to .env, once, because that is the file the user has to fill in and the
# sample is already shaped by the template's own answers. An existing .env is
# never touched, and a template that ships no sample gets nothing.
#
# Branch 2 is the one to watch: its line ends with the test on
# requirements_dev.txt, and a false test with no else returns 0. A failing
# install above it would then be swallowed and reported as a success, which is
# what the `|| exit 1` next to it prevents.
define init_venv
	@if [ -f $(PROJECT_NAME)/uv.lock ] || { [ -f $(PROJECT_NAME)/pyproject.toml ] && grep -qx '\[project\]' $(PROJECT_NAME)/pyproject.toml; }; then \
		echo "🐍 uv project detected (uv.lock or [project] table) — running uv sync..."; \
		cd $(PROJECT_NAME) && uv sync; \
	elif [ -f $(PROJECT_NAME)/requirements.txt ]; then \
		echo "🐍 Creating virtual environment..."; \
		cd $(PROJECT_NAME) && uv venv; \
		echo "📦 Installing dependencies (requirements.txt)..."; \
		uv pip install -r requirements.txt || exit 1; \
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
	@cd $(PROJECT_NAME) && ( [ -f .envrc ] || echo "[ -f .venv/bin/activate ] && source .venv/bin/activate" > .envrc ) && direnv allow
	@cd $(PROJECT_NAME) && ( [ -f .env ] || [ ! -f .env.sample ] || { echo "📝 Creating ./.env from the project's .env.sample..."; cp .env.sample .env; } )
endef

# ==============================================================================
# PROJECT SETUP WORKFLOW
# ==============================================================================
# Location: these targets only run from ~/projects itself — enforced by the
# location gate in the gmake Makefile (same rule as fnew in scaffold.zsh).

copier_project: ## Scaffold a project with Copier from ~/projects (fnew picker)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with Copier..."
	@copier copy $(COPIER_REF_ARG) $(PROJECT_TEMPLATE_REPO) ./$(PROJECT_NAME)
	$(init_venv)
	@echo "✅ Project ready in $(PROJECT_NAME)/"

# Optional pinned template ref/tag: --vcs-ref for Copier, --checkout for Cruft
COPIER_REF_ARG = $(if $(PROJECT_TEMPLATE_VERSION),--vcs-ref $(PROJECT_TEMPLATE_VERSION),)
CHECKOUT_ARG = $(if $(PROJECT_TEMPLATE_VERSION),--checkout $(PROJECT_TEMPLATE_VERSION),)

cruft_project: ## Scaffold a project with Cruft/Cookiecutter from ~/projects (fnew picker)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with Cruft..."
	@cruft create $(PROJECT_TEMPLATE_REPO) $(CHECKOUT_ARG) --extra-context '{"project_name": "$(PROJECT_NAME)", "repo_name": "$(PROJECT_NAME)"}'
	$(init_venv)
	@echo "✅ Project ready in $(PROJECT_NAME)/"

# The `ccds` CLI (cookiecutter-data-science v2) wants its extra context as
# key=value AFTER the template argument, and it asks before running the
# template's hooks - --accept-hooks yes keeps it non-interactive, like copier
# and cruft, which run hooks without asking.
# repo_name is passed explicitly: the template derives it from project_name by
# lowercasing, so a name with an uppercase letter would generate a directory
# that init_venv then cannot find.
ccds_project: ## Scaffold a project with CCDS v2 from ~/projects (fnew picker)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with ccds..."
	@ccds --accept-hooks yes $(CHECKOUT_ARG) -o . $(PROJECT_TEMPLATE_REPO) project_name=$(PROJECT_NAME) repo_name=$(PROJECT_NAME)
	$(init_venv)
	@echo "✅ Project ready in $(PROJECT_NAME)/"