# ==============================================================================
# THE INSTANCE'S OWN WSL SETTINGS
# ==============================================================================
# /etc/wsl.conf is the file WSL reads when the instance starts: which account it
# opens as, what WSL runs at that moment, how the Windows side is reached.
# first_boot.sh writes it whole at the first boot; this is the way back to it.
#
# The file belongs to root: the editor runs under sudo, and nano is named rather
# than $EDITOR - the instance's $EDITOR is `code --wait` whenever VS Code is
# installed, and that `code` is the Windows one seen through /mnt/c. It saves as
# the Windows user, who cannot write a file that belongs to root. A terminal
# editor under sudo can.
#
# It runs from anywhere: the file is the machine's, not a project's, and the
# question "how does this instance start?" is asked from wherever you stand. It
# says so here rather than in the Makefile, like the env_global_* two.
GATE_EXEMPT_GOALS += wsl_config

wsl_config: ## Open /etc/wsl.conf in nano (sudo): default user, boot, interop
	@sudo nano /etc/wsl.conf
	@echo ""
	@echo "ℹ️  WSL reads /etc/wsl.conf when the instance starts — restart it for a change to apply:"
	@echo "   .\wsl.ps1 stop   then   .\wsl.ps1 start"
