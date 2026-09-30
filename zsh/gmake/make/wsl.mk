# ==============================================================================
# THE INSTANCE ITSELF: ITS FILES, ITS STATE, AND ITS SWITCHES
# ==============================================================================
# Everything here is the machine's and not a project's: the three files the
# instance keeps outside ~/.config - /etc/wsl.conf, written whole by
# first_boot.sh at the first boot; /etc/resolv.conf, which answers the DNS; and
# /etc/fstab, the mounts to apply at start - the status that reports what it
# runs on, the ten switches that turn WSL's own features on and off (systemd,
# automount, interop, the Windows PATH, fstab), and the three checks that
# answer for the switches.
#
# The three files belong to root: the editors run under sudo, and nano is named
# rather than $EDITOR - the instance's $EDITOR is `code --wait` whenever VS
# Code is installed, and that `code` is the Windows one seen through /mnt/c.
# It saves as the Windows user, who cannot write a file that belongs to root.
# A terminal editor under sudo can.
#
# All seventeen run from anywhere: what they touch is the machine's, not a
# project's, and "how does this instance start?" is asked from wherever you
# stand. They say so here rather than in the Makefile, like the env_global_*
# two.
GATE_EXEMPT_GOALS += wsl_config dns_resolve wsl_status fstab_config
GATE_EXEMPT_GOALS += systemd_up systemd_down automount_up automount_down interop_up interop_down
GATE_EXEMPT_GOALS += windows_path_up windows_path_down fstab_up fstab_down
GATE_EXEMPT_GOALS += automount_check interop_check windows_path_check

# Commands, not files: one of these names landing in the working directory must
# not turn its target into a no-op.
.PHONY: wsl_config dns_resolve wsl_status fstab_config
.PHONY: systemd_up systemd_down automount_up automount_down interop_up interop_down
.PHONY: windows_path_up windows_path_down fstab_up fstab_down
.PHONY: automount_check interop_check windows_path_check

# The closing line the switches print once the change is written: the command
# that applies it, in green inside a yellow sentence - the colour `gmake help`
# gives a target name is cyan, and green reads as "this is what you type".
# One line, on purpose: it expands inside a recipe's joined command.
define apply_hint
	printf '\033[33mRun \033[32m.\\wsl.ps1 restart\033[33m from Windows to apply.\033[0m\n'
endef

wsl_config: ## Open /etc/wsl.conf in nano (sudo): default user, automount, interop
	@sudo nano /etc/wsl.conf
	@printf '\n\033[33mRun \033[32m.\\wsl.ps1 restart\033[33m from Windows to apply any change.\033[0m\n'

# The resolver file, for the same two reasons and one of its own: it belongs to
# root, and WSL may be the one writing it. As long as it is a symlink - to
# /mnt/wsl/resolv.conf, WSL's own - WSL writes it again at every start of the
# instance, and an edit goes with the next one. The notice says so before the
# editor opens, rather than let a change disappear without a word. The lasting
# way is generateResolvConf = false in /etc/wsl.conf, which wsl_config opens.
dns_resolve: ## Open /etc/resolv.conf in nano (sudo) - the file the instance resolves names with
	@if [ -L /etc/resolv.conf ]; then \
		printf '\033[33mEnsure \033[32mgenerateResolvConf = false\033[33m in /etc/wsl.conf if you want your change to survive a restart.\033[0m\n'; \
	elif [ ! -e /etc/resolv.conf ]; then \
		echo "ℹ️  There is no /etc/resolv.conf — nothing resolves until one exists; WSL will write its own at the next start."; \
	fi
	@sudo nano /etc/resolv.conf

# The mount list, the third file of the same family: root's, read at start only
# when mountFsTab says so. first_boot.sh leaves that setting at false - the
# instance carries no lines in /etc/fstab - so the closing line names the
# switch that turns it on, rather than invite a restart that would mount
# nothing. `sudo mount -a` applies an edit right now, without a restart; the
# page says so.
fstab_config: ## Open /etc/fstab in nano (sudo) - the mounts to apply at start
	@sudo nano /etc/fstab
	@if grep -q '^[[:space:]]*mountFsTab[[:space:]]*=[[:space:]]*true' /etc/wsl.conf 2>/dev/null; then \
		printf '\n\033[33mRun \033[32m.\\wsl.ps1 restart\033[33m from Windows to apply.\033[0m\n'; \
	else \
		printf '\n\033[33mNothing here is mounted at start: set mountFsTab = true first - gmake fstab_up.\033[0m\n'; \
	fi

# The reporter: it reads, it changes nothing, and every probe is one a status
# command has to survive. A state that cannot be read is said plainly - a hole
# or an error halfway down the page would be worse than the answer.
#
# The image ships no systemd; systemd_up, below, installs it. The line says
# what it finds: nothing when it is not installed, `offline` once the packages
# are there and before the restart that boots it.
#
# The block titles are cyan - the colour gmake help gives a target name - so the
# five reads stand apart from the values under them.
wsl_status: ## Show what this instance runs on: base image, init, WSL's files, memory
	@printf '\n\033[36m=== Base Image and the kernel ===\033[0m\n'
	@printf "Kernel     : "; uname -r
	@printf "Base Image : "; grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"'
	@printf '\n\033[36m=== Service Manager ===\033[0m\n'
	@printf "PID 1      : "; ps -p 1 -o comm= || true
	@printf "systemd    : "; state=$$(systemctl is-system-running 2>/dev/null || true); \
		if [ -n "$$state" ]; then echo "$$state"; else echo "not installed - gmake systemd_up adds it"; fi
	@printf '\n\033[36m=== /etc/wsl.conf (local) ===\033[0m\n'
	@if [ -f /etc/wsl.conf ]; then cat /etc/wsl.conf; else echo "No such file - WSL starts with its defaults."; fi
	@printf '\n\033[36m=== %%USERPROFILE%%\\.wslconfig (windows) ===\033[0m\n'
	@if ! powershell.exe -NoProfile -Command 'exit 0' >/dev/null 2>&1; then \
		echo "Windows is not reachable from here - interop is off, or there is no Windows."; \
	else \
		win_home=$$(powershell.exe -NoProfile -Command '$$env:USERPROFILE' 2>/dev/null | tr -d '\r'); \
		drive=$$(printf '%s' "$$win_home" | cut -c1 | tr 'A-Z' 'a-z'); \
		rest=$$(printf '%s' "$$win_home" | cut -c3- | tr '\\' '/'); \
		wslconfig=/mnt/$$drive$$rest/.wslconfig; \
		if [ -z "$$win_home" ]; then \
			echo "Windows did not answer - nothing to read."; \
		elif [ -f "$$wslconfig" ]; then \
			cat "$$wslconfig"; \
		else \
			echo "No $$wslconfig - WSL runs with its own defaults (.\wsl.ps1 wslconfig creates it)."; \
		fi; \
	fi
	@printf '\n\033[36m=== Memory and services ===\033[0m\n'
	@printf "Memory     : "; free -h | awk '/^Mem:/ {print $$3 "/" $$2 " in use"}'
	@if systemctl is-system-running >/dev/null 2>&1; then \
		printf "Services   : %s running, %s failed\n" "$$(systemctl list-units --type=service --state=running --no-legend | wc -l)" "$$(systemctl --failed --no-legend | wc -l)"; \
	else \
		printf "Services   : %s up under init.d (systemd is not running)\n" "$$(service --status-all 2>/dev/null | grep -c '\[ + \]')"; \
	fi
	@printf '\n'

# ==============================================================================
# THE TEN SWITCHES - WSL'S OWN FEATURES, TURNED ON AND OFF
# ==============================================================================
# Each pair edits one line of /etc/wsl.conf and nothing else in it, and each
# takes effect at the next start - WSL reads the file when the instance boots.
# The pairs are named up and down like the web pack's vpn_up and vpn_down.
#
# The edit the ten share: read /etc/wsl.conf into $new, with `$(2)` set to
# `$(3)` inside the `[$(1)]` section - the line replaced where it exists in that
# section, inserted under its header where it does not, and the section appended
# when the file has none. Nothing else moves: the other sections and the
# comments come back untouched.
#
# Section-aware on purpose: `enabled` lives in [automount] and in [interop], and
# a replacement matching on the key alone would hit both. And two passes,
# because one pass cannot know whether to insert under the header - it would
# insert AND replace, and the file would grow a line per run (measured).
#
# The awk programs stay on one line on purpose: inside single quotes, sh keeps
# a backslash, and a multi-line program would need one per line to cross the
# recipe.
#   $(1) the section   $(2) the key   $(3) the value
define wsl_conf_set
	if [ -f /etc/wsl.conf ]; then \
		has=$$(awk -v sec="$(1)" -v key="$(2)" 'BEGIN { ins = 0 } /^\[/ { ins = ($$0 ~ "^\\[[[:space:]]*" sec "[[:space:]]*\\]") } ins && $$0 ~ ("^[[:space:]]*" key "[[:space:]]*=") { c++ } END { print c + 0 }' /etc/wsl.conf); \
		new=$$(awk -v sec="$(1)" -v key="$(2)" -v val="$(3)" -v has="$$has" '/^\[/ { if ($$0 ~ "^\\[[[:space:]]*" sec "[[:space:]]*\\]") { print; if (!has) { print key "=" val; seen = 1 }; ins = 1; next } ins = 0; print; next } ins && $$0 ~ ("^[[:space:]]*" key "[[:space:]]*=") { print key "=" val; seen = 1; next } { print } END { if (!seen) { print ""; print "[" sec "]"; print key "=" val } }' /etc/wsl.conf); \
	else \
		new=$$(printf '[$(1)]\n$(2)=$(3)'); \
	fi
endef

# systemd, on demand: the image ships none, and that is deliberate - nothing it
# starts is a service, and the `systemd` package alone never boots anything
# anyway (WSL runs the distribution's /sbin/init, which `systemd-sysv` poses).
# What it brings when it is on: the standard way to run a service - start it
# with the instance, restart it when it falls, log to journalctl, schedule
# timers. What it costs: about 22 MB of packages, and PID 1 changes at the next
# start.
#
# Three packages, named, with --no-install-recommends like every apt line of the
# image: systemd-sysv poses /sbin/init, and libpam-systemd and dbus-user-session
# are what a user session needs - without them WSL says "Failed to start the
# systemd user session" at every start (measured on an instance, 2026-09-30).
# Naming them is also what keeps systemd-resolved out, a rival of the resolver
# the web pack installs (openresolv): it is only ever a recommendation.
#
# One sudo, and the file is only written once the packages are there: a
# half-enabled instance is not a state to leave behind.
#
# The words speak of the state the user cares about, not of the packages:
# installing says nothing once it is done, and "already enabled" is not read
# from the file - PID 1 is asked. A running systemd answers alone; a flag in a
# file answers nothing.
#
# Two units are masked along the way - kmod-static-nodes (WSL owns /dev) and
# systemd-binfmt (no binfmt_misc here). They can never succeed, and left alone
# they make `systemctl is-system-running` answer `degraded` instead of
# `running`. reset-failed clears them from the running boot, so the word turns
# clean without waiting for a restart.
systemd_up: ## Install systemd and turn it on for this instance (a restart boots it)
	@$(call wsl_conf_set,boot,systemd,true); \
	installed=0; \
	if dpkg -s systemd-sysv libpam-systemd dbus-user-session >/dev/null 2>&1; then \
		installed=1; \
	else \
		echo ""; \
		echo "Installing systemd, please wait..."; \
		tmp=$$(mktemp); printf '%s\n' "$$new" > "$$tmp"; \
		sudo sh -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y --no-install-recommends systemd-sysv libpam-systemd dbus-user-session && cat > /etc/wsl.conf' < "$$tmp"; \
		rc=$$?; rm -f "$$tmp"; \
		[ $$rc -eq 0 ] || { echo ""; echo "❌ The installation failed — /etc/wsl.conf was left untouched."; exit 1; }; \
	fi; \
	if [ "$$(systemctl is-enabled kmod-static-nodes 2>/dev/null)" != "masked" ] || [ "$$(systemctl is-enabled systemd-binfmt 2>/dev/null)" != "masked" ]; then \
		echo ""; \
		echo "Masking the two units WSL cannot use: kmod-static-nodes, systemd-binfmt."; \
		sudo sh -c 'systemctl mask kmod-static-nodes systemd-binfmt >/dev/null; systemctl reset-failed kmod-static-nodes systemd-binfmt 2>/dev/null || true'; \
	fi; \
	if [ "$$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]; then \
		echo "systemd is already enabled."; \
		exit 0; \
	fi; \
	if [ $$installed -eq 1 ]; then \
		printf '%s\n' "$$new" | sudo tee /etc/wsl.conf >/dev/null; \
	fi; \
	echo ""; \
	echo "✅ systemd is enabled."; \
	$(call apply_hint)

systemd_down: ## Stop booting systemd for this instance (the packages stay installed)
	@$(call wsl_conf_set,boot,systemd,false); \
	if ! grep -q '^[[:space:]]*systemd[[:space:]]*=' /etc/wsl.conf 2>/dev/null; then \
		echo "systemd is not declared in /etc/wsl.conf - it is already off."; \
		exit 0; \
	fi; \
	if [ "$$new" = "$$(cat /etc/wsl.conf)" ]; then \
		echo "systemd is already off for this instance."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$new" | sudo tee /etc/wsl.conf >/dev/null; \
	echo ""; \
	echo "✅ systemd is off. The packages stay installed."; \
	$(call apply_hint)

automount_up: ## Mount the Windows drives under /mnt at every start (the default)
	@$(call wsl_conf_set,automount,enabled,true); \
	if [ "$$new" = "$$(cat /etc/wsl.conf 2>/dev/null)" ]; then \
		echo "automount is already on for this instance."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$new" | sudo tee /etc/wsl.conf >/dev/null; \
	echo ""; \
	echo "✅ automount is on."; \
	$(call apply_hint)

automount_down: ## Stop mounting the Windows drives (no more /mnt/c)
	@$(call wsl_conf_set,automount,enabled,false); \
	if [ "$$new" = "$$(cat /etc/wsl.conf 2>/dev/null)" ]; then \
		echo "automount is already off for this instance."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$new" | sudo tee /etc/wsl.conf >/dev/null; \
	echo ""; \
	echo "✅ automount is off."; \
	$(call apply_hint)

# The three checks answer for the switches from the machine, not from the file:
# what is mounted, what runs, what is in the PATH. They change nothing, take no
# password, and one line comes out either way - the folders under /mnt are
# empty when automount is off, so the mount table is what is asked, not `ls`.
# And the filesystem's own name is not asked: it was drvfs once and is 9p now,
# and a drive is a drive either way - a single letter under /mnt is the sign.
automount_check: ## Say whether the Windows drives are mounted under /mnt
	@drives=$$(mount | sed -n 's|.* on /mnt/\([a-z]\) .*|\1|p' | sort -u | paste -sd, -); \
	if [ -n "$$drives" ]; then \
		echo "automount: mounted - the Windows drives ($$drives) are under /mnt."; \
	else \
		echo "automount: not mounted - the folders under /mnt are empty."; \
	fi

interop_up: ## Let the instance run Windows programs (the default)
	@$(call wsl_conf_set,interop,enabled,true); \
	if [ "$$new" = "$$(cat /etc/wsl.conf 2>/dev/null)" ]; then \
		echo "interop is already on for this instance."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$new" | sudo tee /etc/wsl.conf >/dev/null; \
	echo ""; \
	echo "✅ interop is on."; \
	$(call apply_hint)

interop_down: ## Stop running Windows programs from the instance
	@$(call wsl_conf_set,interop,enabled,false); \
	if [ "$$new" = "$$(cat /etc/wsl.conf 2>/dev/null)" ]; then \
		echo "interop is already off for this instance."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$new" | sudo tee /etc/wsl.conf >/dev/null; \
	echo ""; \
	echo "✅ interop is off."; \
	$(call apply_hint)

# Interop is tried for real - a Windows binary is run - and the file is not
# read. cmd.exe off a mounted drive first, because it works whatever the PATH
# says; powershell.exe after, for an instance whose drives are out but whose
# PATH is in. When neither is reachable, that is the answer.
interop_check: ## Say whether Windows programs can be run from this instance
	@if [ -x /mnt/c/Windows/System32/cmd.exe ]; then \
		if /mnt/c/Windows/System32/cmd.exe /c exit 0 >/dev/null 2>&1; then \
			echo "interop: on - a Windows program runs from here."; \
		else \
			echo "interop: off - the Windows drives are there, and nothing of theirs runs."; \
		fi; \
	elif command -v powershell.exe >/dev/null 2>&1; then \
		if powershell.exe -NoProfile -Command 'exit 0' >/dev/null 2>&1; then \
			echo "interop: on - a Windows program runs from here."; \
		else \
			echo "interop: off - powershell.exe is on the PATH and does not run."; \
		fi; \
	else \
		echo "interop: nothing runs here - no drive is mounted and the Windows PATH is out."; \
	fi

windows_path_up: ## Add the Windows PATH to this instance's PATH (the default)
	@$(call wsl_conf_set,interop,appendWindowsPath,true); \
	if [ "$$new" = "$$(cat /etc/wsl.conf 2>/dev/null)" ]; then \
		echo "the Windows PATH is already appended here."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$new" | sudo tee /etc/wsl.conf >/dev/null; \
	echo ""; \
	echo "✅ the Windows PATH is appended."; \
	$(call apply_hint)

windows_path_down: ## Keep the Windows PATH out of this instance's PATH (interop stays on)
	@$(call wsl_conf_set,interop,appendWindowsPath,false); \
	if [ "$$new" = "$$(cat /etc/wsl.conf 2>/dev/null)" ]; then \
		echo "the Windows PATH is already out here."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$new" | sudo tee /etc/wsl.conf >/dev/null; \
	echo ""; \
	echo "✅ the Windows PATH is out."; \
	$(call apply_hint)

# Asked of the PATH itself: an entry under /mnt means the Windows folders are
# in it, whatever the file says.
windows_path_check: ## Say whether the Windows PATH is in this instance's PATH
	@dirs=$$(printf '%s' "$$PATH" | tr ':' '\n' | grep -c '^/mnt/'); \
	if [ "$$dirs" -gt 0 ]; then \
		echo "windows_path: appended - $$dirs entries from /mnt are in the PATH."; \
	else \
		echo "windows_path: not appended - nothing from /mnt is in the PATH."; \
	fi

fstab_up: ## Apply /etc/fstab at every start (off until you say so)
	@$(call wsl_conf_set,automount,mountFsTab,true); \
	if [ "$$new" = "$$(cat /etc/wsl.conf 2>/dev/null)" ]; then \
		echo "the fstab entries are already applied at start."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$new" | sudo tee /etc/wsl.conf >/dev/null; \
	echo ""; \
	echo "✅ the fstab entries are applied at start."; \
	$(call apply_hint)

fstab_down: ## Leave /etc/fstab alone at start (the default)
	@$(call wsl_conf_set,automount,mountFsTab,false); \
	if [ "$$new" = "$$(cat /etc/wsl.conf 2>/dev/null)" ]; then \
		echo "the fstab entries are already left alone at start."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$new" | sudo tee /etc/wsl.conf >/dev/null; \
	echo ""; \
	echo "✅ the fstab entries are left alone at start."; \
	$(call apply_hint)
