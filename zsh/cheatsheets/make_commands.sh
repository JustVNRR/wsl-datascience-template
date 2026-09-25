# ==========================================
# MAKEFILE CHEATSHEET (via alias gmake)
# ==========================================
# The socle's gmake targets: the ones that need no pack. What a pack brings has
# its sheet in the pack's own folder - the python pack's lint and test lanes
# among them - and the Google Cloud ones live in gcp_commands.sh, which is
# offered only while that CLI is installed.

# --- 1. DOCKER (LOCAL IMAGES) ---
gmake docker_build_local                     # Build Docker image for local development environment
gmake docker_run_local                       # Run Docker container locally

# --- 2. GITHUB CLI (PULL REQUESTS) ---
gmake gh_pr_create                           # Create a new Pull Request on GitHub
gmake gh_pr_toreview                         # Mark a Pull Request as ready for review
gmake gh_pr_wip                              # Convert a Pull Request back to draft status (WIP)
gmake gh_pr_ls                               # List all open Pull Requests in the repository

# --- 3. ENVIRONMENT FILES (.env.global / .env) ---
gmake env_global_enable                      # Create or complete the machine-wide .env.global from the samples
gmake env_project_enable                     # Create or complete this project's .env from the samples

# --- 4. PACKS ---
gmake packs_list                             # List the packs this instance carries
