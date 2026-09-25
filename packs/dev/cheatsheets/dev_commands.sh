# ==========================================
# THE PROJECT TARGETS (the dev pack)
# ==========================================
# What a project is built, pushed and configured with. All of them run from the
# root of a project under ~/projects - except env_global_enable, which writes a
# machine-wide file and runs from anywhere.

# --- 1. ENVIRONMENT FILES (.env.global / .env) ---
gmake env_global_enable                      # Create or complete the machine-wide .env.global from the samples
gmake env_project_enable                     # Create or complete this project's .env from the samples

# --- 2. DOCKER (LOCAL IMAGES) ---
gmake docker_build_local                     # Build Docker image for local development environment
gmake docker_run_local                       # Run Docker container locally

# --- 3. GITHUB CLI (PULL REQUESTS) ---
gmake gh_pr_create                           # Create a new Pull Request on GitHub
gmake gh_pr_toreview                         # Mark a Pull Request as ready for review
gmake gh_pr_wip                              # Convert a Pull Request back to draft status (WIP)
gmake gh_pr_ls                               # List all open Pull Requests in the repository
