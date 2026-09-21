# ==============================================================================
# 🧹 LINT
# ==============================================================================
# Python : ruff — installed globally at first boot via `uv tool install ruff`;
#   rules are configured per-project in pyproject.toml ([tool.ruff]).
# Shell  : shellcheck — preinstalled in the template image.
#   Debian/Ubuntu/WSL : sudo apt-get install shellcheck
#   macOS             : brew install shellcheck

# Default scan roots (can be overridden from the command line)
PY_TARGETS ?= .
SH_TARGETS ?= .

# Full-scan confirmation: bare targets (default roots ".") prompt before scanning the
# whole directory. When `lint` is the goal, its lint-confirm prerequisite asks ONCE
# and the individual checks stay silent (LINT_AGGREGATE) — no cascade, no sub-make.
# Scope instead, e.g.: gmake lint PY_TARGETS="src/" SH_TARGETS="scripts/"
ifneq ($(filter lint,$(MAKECMDGOALS)),)
LINT_AGGREGATE = 1
endif

.PHONY: lint lint-confirm lint-py lint-sh lint-format

lint: lint-confirm lint-sh lint-py ## Run all checks (Python + shell), non-destructive (confirms full-directory scans)

# Internal prerequisite of `lint`: the single full-scan confirmation prompt
lint-confirm:
	@if [ "$(PY_TARGETS)" = "." ] || [ "$(SH_TARGETS)" = "." ]; then \
		echo "⚠️  No scope given for:$(if $(filter .,$(PY_TARGETS)), python)$(if $(filter .,$(SH_TARGETS)), shell)"; \
		echo "    The scan covers the ENTIRE current directory ($(CURDIR))."; \
		echo "    To scope it, relaunch with e.g. gmake lint PY_TARGETS=\"src/\" SH_TARGETS=\"scripts/\""; \
		read -p "Continue with the full scan? [y/N] " ans; \
		if [ "$$ans" != "y" ] && [ "$$ans" != "Y" ]; then echo "❌ Cancelled by user." >&2; exit 1; fi; \
	fi

lint-py: ## Check Python code with ruff (optional: PY_TARGETS="...")
	@if [ "$(LINT_AGGREGATE)" != "1" ] && [ "$(PY_TARGETS)" = "." ]; then \
		echo "⚠️  No scope given: lint-py will scan the ENTIRE current directory ($(CURDIR))."; \
		echo "    To scope it, relaunch with e.g. gmake lint-py PY_TARGETS=\"src/\""; \
		read -p "Continue with the full scan? [y/N] " ans; \
		if [ "$$ans" != "y" ] && [ "$$ans" != "Y" ]; then echo "❌ Cancelled by user." >&2; exit 1; fi; \
	fi
	@command -v ruff >/dev/null 2>&1 || { \
		echo "❌ ruff is not installed. Install: uv tool install ruff" >&2; \
		exit 1; \
	}
	@echo "🔍 Running Ruff on: $(PY_TARGETS)"
	ruff check --no-fix $(PY_TARGETS)
	ruff format --check $(PY_TARGETS)

lint-sh: ## Check shell scripts with shellcheck (optional: SH_TARGETS="...")
	@if [ "$(LINT_AGGREGATE)" != "1" ] && [ "$(SH_TARGETS)" = "." ]; then \
		echo "⚠️  No scope given: lint-sh will scan the ENTIRE current directory ($(CURDIR))."; \
		echo "    To scope it, relaunch with e.g. gmake lint-sh SH_TARGETS=\"scripts/\""; \
		read -p "Continue with the full scan? [y/N] " ans; \
		if [ "$$ans" != "y" ] && [ "$$ans" != "Y" ]; then echo "❌ Cancelled by user." >&2; exit 1; fi; \
	fi
	@# Resolve the scan roots at RUN time - a shell variable, never a make-level
	@# shell call. A `#` comments for the shell, not for make: make expands a
	@# whole recipe before any of its lines runs, so such a call would execute
	@# before the confirmation prompt above could be answered.
	@files=$$(find $(SH_TARGETS) -type f -name "*.sh" -not -path "*/.*/*" -not -path "*/venv/*" 2>/dev/null); \
	if [ -z "$$files" ]; then \
		echo "ℹ️  No shell scripts found to analyze."; \
	else \
		command -v shellcheck >/dev/null 2>&1 || { \
			echo "❌ shellcheck is not installed. Debian/Ubuntu/WSL: sudo apt-get install shellcheck — macOS: brew install shellcheck" >&2; \
			exit 1; \
		}; \
		echo "🔍 Running ShellCheck on: $$files"; \
		shellcheck -x $$files; \
	fi

lint-format: ## Auto-fix and format Python code with ruff (optional: PY_TARGETS="...")
	@command -v ruff >/dev/null 2>&1 || { \
		echo "❌ ruff is not installed. Install: uv tool install ruff" >&2; \
		exit 1; \
	}
	@echo "🧹 Formatting with Ruff on: $(PY_TARGETS)"
	ruff check --fix $(PY_TARGETS)
	ruff format $(PY_TARGETS)
