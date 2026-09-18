# ==========================================
# MAKEFILE CHEATSHEET (via alias gmake)
# ==========================================
# The gmake targets that need no Google Cloud CLI. The ones that do live in
# gcp_commands.sh, which is offered only while that CLI is installed.

# --- 1. DOCKER (LOCAL & PRODUCTION IMAGES) ---
gmake docker_build_local                     # Build Docker image for local development environment
gmake docker_run_local                       # Run Docker container locally
gmake docker_build_prod                      # Build production-optimized Docker image
gmake docker_push_prod                       # Push production image to Artifact Registry

# --- 2. GITHUB CLI (PULL REQUESTS) ---
gmake gh_pr_create                           # Create a new Pull Request on GitHub
gmake gh_pr_toreview                         # Mark a Pull Request as ready for review
gmake gh_pr_wip                              # Convert a Pull Request back to draft status (WIP)
gmake gh_pr_ls                               # List all open Pull Requests in the repository

# --- 3. LINT (RUFF & SHELLCHECK) ---
gmake lint                                   # Run all lint checks (Python + shell), non-destructive
gmake lint-py                                # Check Python code with ruff (PY_TARGETS="..." to scope)
gmake lint-sh                                # Check shell scripts with shellcheck (SH_TARGETS="..." to scope)
gmake lint-format                            # Auto-fix and format Python code with ruff

# --- 4. TESTS (PYTEST) ---
gmake test                                   # Run the whole test suite
gmake test-fast                              # Run fast tests only, without external infrastructure (CI lane)
gmake test-functional                        # Run functional tests (real local infra needed, e.g. .env, Docker, model)
gmake test-gcp                               # Run tests hitting a real GCP environment (test/staging/prod)
