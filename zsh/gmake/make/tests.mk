# ==============================================================================
# 🧪 TESTS
# ==============================================================================
# pytest is a project dependency, not a machine tool (unlike ruff): it must run
# inside the project's virtual environment to import its code and plugins.
# Install it per project: uv add --dev pytest
#
# Marker convention — register the markers used by each project in its
# pyproject.toml ([tool.pytest.ini_options] markers):
#   (none)      fast unit tests, no external infrastructure (CI lane)
#   functional  needs real local infra (.env, Docker, a trained model...)
#   gcp         hits a real GCP environment (test/staging/prod)
# Unmarked tests run in `test` and `test-fast`; the functional and gcp lanes
# select their marker, so a project that declares none collects nothing there
# (pytest exits 5). The convention stays optional: pytest only warns about
# markers it does not know.

.PHONY: test test-fast test-functional test-gcp

# Fail fast when pytest is missing from the active environment (project venv)
define assert_pytest
	@command -v pytest >/dev/null 2>&1 || { \
		echo "❌ pytest not found." >&2; \
		echo "   Make sure you're in the project folder and try again." >&2; \
		echo "   Or add pytest to the project: uv add --dev pytest" >&2; \
		exit 1; \
	}
endef

test: ## Run the whole test suite
	$(call assert_pytest)
	@echo "🧪 Running the full test suite..."
	pytest

test-fast: ## Run fast tests only, without external infrastructure (CI lane)
	$(call assert_pytest)
	@echo "⚡ Running fast tests (no external infrastructure)..."
	pytest -m "not functional and not gcp"

test-functional: ## Run functional tests (real local infra needed, e.g. .env, Docker, model)
	$(call assert_pytest)
	@echo "🔌 Running functional tests (real local infrastructure needed)..."
	pytest -m "functional and not gcp"

test-gcp: ## Run tests hitting a real GCP environment (test/staging/prod)
	$(call assert_pytest)
	@echo "⚠️  Running tests against a REAL GCP environment..."
	pytest -m gcp
