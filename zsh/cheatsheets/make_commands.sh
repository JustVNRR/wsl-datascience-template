# ==========================================
# MAKEFILE CHEATSHEET (via alias gmake)
# ==========================================
# The socle's gmake targets: the ones that need no pack, which today is one. A
# pack brings its targets and its sheet together, in its own folder: the
# project targets (Docker, GitHub, the environment files) are in the dev pack's
# sheet, the lint and test lanes in the python pack's, the Google Cloud ones in
# gcp_commands.sh, offered only while that CLI is installed.

# --- 1. PACKS ---
gmake packs_list                             # List the packs this instance carries
