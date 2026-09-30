# ==========================================
# MAKEFILE CHEATSHEET (the gmake targets)
# ==========================================
# The socle's gmake targets: the ones that need no pack, which today is fourteen. A
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

# --- 3. WSL CONFIGURATION AND STATUS (/etc/wsl.conf, /etc/resolv.conf) ---
gmake wsl_config                             # Open /etc/wsl.conf in nano (sudo): default user, automount, interop
gmake dns_resolve                            # Open /etc/resolv.conf in nano (sudo): the file the instance resolves names with
gmake wsl_status                             # Show what this instance runs on (kernel, init, WSL's files, memory)

# --- 4. THE SWITCHES (they take effect at the next start) ---
gmake systemd_up                             # Install systemd and turn it on for this instance (a restart boots it)
gmake systemd_down                           # Stop booting systemd (the packages stay installed)
gmake automount_up                           # Mount the Windows drives under /mnt at every start (the default)
gmake automount_down                         # Stop mounting the Windows drives (no more /mnt/c)
gmake interop_up                             # Let the instance run Windows programs (the default)
gmake interop_down                           # Stop running Windows programs from the instance
