# ==============================================================================
# THE INSTANCE'S OWN FILES, OUTSIDE ~/.config
# ==============================================================================
# Two files WSL reads and no project owns: /etc/wsl.conf - which account the
# instance opens as, what WSL runs at that moment, how the Windows side is
# reached, written whole by first_boot.sh at the first boot - and
# /etc/resolv.conf, which answers the instance's DNS questions.
#
# Both belong to root: the editors run under sudo, and nano is named rather
# than $EDITOR - the instance's $EDITOR is `code --wait` whenever VS Code is
# installed, and that `code` is the Windows one seen through /mnt/c. It saves
# as the Windows user, who cannot write a file that belongs to root. A
# terminal editor under sudo can.
#
# Both targets run from anywhere: these files are the machine's, not a
# project's, and "how does this instance start?" and "what answers its DNS?"
# are asked from wherever you stand. They say so here rather than in the
# Makefile, like the env_global_* two.
GATE_EXEMPT_GOALS += wsl_config dns_resolve

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
