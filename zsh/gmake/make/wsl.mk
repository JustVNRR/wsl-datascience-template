# ==============================================================================
# THE INSTANCE ITSELF: THE FILES WSL READS, AND WHAT IT RUNS ON
# ==============================================================================
# Two files WSL reads and no project owns: /etc/wsl.conf - which account the
# instance opens as, what WSL runs at that moment, how the Windows side is
# reached, written whole by first_boot.sh at the first boot - and
# /etc/resolv.conf, which answers the instance's DNS questions. The third
# target changes neither: wsl_status reads the instance and prints what it
# found.
#
# The two files belong to root: the editors run under sudo, and nano is named
# rather than $EDITOR - the instance's $EDITOR is `code --wait` whenever VS
# Code is installed, and that `code` is the Windows one seen through /mnt/c.
# It saves as the Windows user, who cannot write a file that belongs to root.
# A terminal editor under sudo can.
#
# The three run from anywhere: what they read is the machine's, not a
# project's, and "how does this instance start?", "what answers its DNS?" and
# "what does it run on?" are asked from wherever you stand. They say so here
# rather than in the Makefile, like the env_global_* two.
GATE_EXEMPT_GOALS += wsl_config dns_resolve wsl_status

# Commands, not files: one of these names landing in the working directory
# must not turn its target into a no-op.
.PHONY: wsl_config dns_resolve wsl_status

wsl_config: ## Open /etc/wsl.conf in nano (sudo): default user, boot, interop
	@sudo nano /etc/wsl.conf
	@echo ""
	@echo "ℹ️  WSL reads /etc/wsl.conf when the instance starts — restart it for a change to apply:"
	@echo "   .\wsl.ps1 restart   (from Windows)"

# The resolver file, for the same two reasons and one of its own: it belongs
# to root, and WSL may be the one writing it. As long as it is a symlink - to
# /mnt/wsl/resolv.conf, WSL's own - WSL writes it again at every start of the
# instance, and an edit goes with the next one. The notice says so before the
# editor opens, rather than let a change disappear without a word. The lasting
# way is generateResolvConf = false in /etc/wsl.conf, which wsl_config opens.
dns_resolve: ## Open /etc/resolv.conf in nano (sudo) - the file the instance resolves names with
	@if [ -L /etc/resolv.conf ]; then \
		echo "ℹ️  WSL owns this file — a symlink to $$(readlink /etc/resolv.conf), written again at every start of the instance."; \
		echo "   A change that must survive a restart: generateResolvConf = false in /etc/wsl.conf (gmake wsl_config)."; \
	elif [ ! -e /etc/resolv.conf ]; then \
		echo "ℹ️  There is no /etc/resolv.conf — nothing resolves until one exists; WSL will write its own at the next start."; \
	fi
	@sudo nano /etc/resolv.conf

# The reporter: it reads, it changes nothing, and every probe is one a status
# command has to survive. A state that cannot be read is said plainly - a hole
# or an error halfway down the page would be worse than the answer.
#
# The image ships no systemd (see make/systemd.mk): the systemd line is empty
# until `gmake systemd_enable` installs the packages, and reads `offline` from
# there until the instance restarts into it. The line reports what it finds.
wsl_status: ## Show what this instance runs on: kernel, init, WSL's files, memory
	@echo ""
	@echo "=== The distribution and the kernel ==="
	@printf "Kernel     : "; uname -r
	@printf "Distro     : "; grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"'
	@echo ""
	@echo "=== Init and systemd ==="
	@printf "PID 1      : "; ps -p 1 -o comm= || true
	@printf "systemd    : "; state=$$(systemctl is-system-running 2>/dev/null || true); \
		if [ -n "$$state" ]; then echo "$$state"; else echo "not installed - gmake systemd_enable adds it"; fi
	@echo ""
	@echo "=== The local file (/etc/wsl.conf) ==="
	@if [ -f /etc/wsl.conf ]; then cat /etc/wsl.conf; else echo "No such file - WSL starts with its defaults."; fi
	@echo ""
	@echo "=== The Windows-wide file (%USERPROFILE%\.wslconfig) ==="
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
			echo "No $$wslconfig - WSL runs with its own defaults."; \
		fi; \
	fi
	@echo ""
	@echo "=== Memory and services ==="
	@printf "Memory     : "; free -h | awk '/^Mem:/ {print $$3 "/" $$2 " in use"}'
	@if systemctl is-system-running >/dev/null 2>&1; then \
		printf "Services   : %s running, %s failed\n" "$$(systemctl list-units --type=service --state=running --no-legend | wc -l)" "$$(systemctl --failed --no-legend | wc -l)"; \
	else \
		printf "Services   : %s up under init.d (systemd is not running)\n" "$$(service --status-all 2>/dev/null | grep -c '\[ + \]')"; \
	fi
	@echo ""
