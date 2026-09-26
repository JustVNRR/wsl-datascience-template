# ==============================================================================
# THE VIRTUAL ENVIRONMENT
# ==============================================================================
# What the python pack adds once the scaffolding act has copied a template and
# written the project's .env. This macro is the whole of it: the act itself -
# the picker, the three targets, the catalogs - is the scaffold pack's, and it
# calls this one through the declaration below.

# init_venv: detect the project's dependency manifest and bootstrap its environment.
# Exactly one branch installs dependencies:
#   1. uv.lock, or a PEP 621 [project] table  ->  uv sync (creates .venv,
#      installs dependencies + the dev group by default)
#   2. requirements.txt                        ->  uv venv + uv pip install
#      (+ requirements_dev.txt when present)
#   3. no recognized manifest                  ->  bare uv venv, with a warning
#
# Branch 2 is the one to watch: its line ends with the test on
# requirements_dev.txt, and a false test with no else returns 0. A failing
# install above it would then be swallowed and reported as a success, which is
# what the `|| exit 1` next to it prevents.
#
# The direnv hook comes last, and it writes over nothing that is already there:
# our own template ships an .envrc that also loads .env through dotenv, and
# another template's .envrc is its own business. Ours - the line that activates
# the venv this macro just created - is written only where there is none, with
# the guard that keeps it quiet before the first `uv sync`, and then approved, so
# the project is usable on the way in. That line is why the hook is here and not
# in the generic after-copy step: it is Python's, and a template that ships no
# .envrc is the only case that ever sees it.
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
endef

# What runs once a template has been copied is declared by the pack that curates
# the row, here, beside the macro it names - so the two cannot drift apart. The
# scaffold pack reads the declaration off the row `fnew` picked and calls it;
# called directly, the target names the pack in TEMPLATE_PACK. Nothing else
# writes the name of this macro anywhere.
SCAFFOLD_AFTER_python := init_venv
