# ==========================================
# MAKEFILE CHEATSHEET (the gmake targets)
# ==========================================
# The socle's gmake targets: the ones that need no pack, which today is five. A
# pack brings its targets and its sheet together, in its own folder: the project
# targets (Docker, GitHub) are in the devops pack's sheet, the lint and test
# lanes in the python pack's, the Google Cloud ones in gcp_commands.sh, offered
# only while that CLI is installed.

# --- 1. PACKS ---
gmake packs_list                             # List the packs this instance carries

# --- 2. ENVIRONMENT FILES (.env.global / .env) ---
gmake env_global_enable                      # Create or complete the machine-wide .env.global from the samples
gmake env_global_manage                      # Create or complete it, then open the machine-wide .env.global in the editor
gmake env_project_enable                     # Create or complete this project's .env from the samples
gmake env_project_manage                     # Create or complete it, then open this project's .env in the editor
