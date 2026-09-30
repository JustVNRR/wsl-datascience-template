# ==============================================================================
# SYSTEMD, ON DEMAND
# ==============================================================================
# The image ships no systemd, and that is deliberate: nothing it starts is a
# service, and the `systemd` package alone never boots anything - WSL runs the
# distribution's /sbin/init, which the `systemd-sysv` package poses. The
# instance that wants services installs both from here.
#
# What systemd brings when it is on: the standard way to run a service - it
# starts with the instance, restarts when it falls, logs to journalctl,
# schedules timers. What it costs: about 19 MB of packages, and PID 1 changes
# at the next start.
#
# --no-install-recommends, like every apt line of the image: what systemd merely
# recommends includes systemd-resolved, and that one is a rival of the resolver
# the web pack installs (openresolv) - turning systemd on must not drag it in
# by surprise.
#
# Both targets edit /etc/wsl.conf and nothing else in it: the other sections and
# the comments come back untouched, and the [boot] block is created only when
# the file has none. Both run from anywhere - the setting is the machine's, not
# a project's, like the env_global_* two.
GATE_EXEMPT_GOALS += systemd_enable systemd_disable
.PHONY: systemd_enable systemd_disable

# The edit, shared by the two targets: read /etc/wsl.conf into $new, with the
# [boot] block holding `systemd=$(1)` - the line replaced where it exists,
# inserted under the block's header where it does not, and the block appended
# when the file has none.
#
# Two passes on purpose: grep counts the systemd lines first, because one pass
# over the file cannot know whether to insert under the header - it would insert
# AND replace, and the file would grow a line per run.
#
# The awk program stays on one line on purpose: inside single quotes, sh keeps a
# backslash, and a multi-line program would need one per line to cross the recipe.
define systemd_line
	if [ -f /etc/wsl.conf ]; then \
		has=$$(grep -c '^[[:space:]]*systemd[[:space:]]*=' /etc/wsl.conf || true); \
		new=$$(awk -v line="systemd=$(1)" -v has="$$has" '/^[[:space:]]*systemd[[:space:]]*=/ { print line; seen = 1; next } { print } /^\[[[:space:]]*boot[[:space:]]*\]/ { if (!has) { print line; seen = 1 } } END { if (!seen && !has) { print ""; print "[boot]"; print line } }' /etc/wsl.conf); \
	else \
		new=$$(printf '[boot]\nsystemd=$(1)'); \
	fi
endef

systemd_enable: ## Install systemd and turn it on for this instance (a restart boots it)
	@echo ""
	@echo "Installing systemd (systemd + systemd-sysv, about 19 MB) and turning it on."
	@echo "Your password will be asked, once."
	@$(call systemd_line,true); \
	tmp=$$(mktemp); printf '%s\n' "$$new" > "$$tmp"; \
	sudo sh -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y --no-install-recommends systemd-sysv && cat > /etc/wsl.conf' < "$$tmp"; \
	rc=$$?; rm -f "$$tmp"; \
	[ $$rc -eq 0 ] || { echo ""; echo "❌ The installation failed — /etc/wsl.conf was left untouched."; exit 1; }
	@echo ""
	@echo "✅ systemd will start with the instance — restart it for that:  .\wsl.ps1 restart"
	@echo "   gmake wsl_status says whether it is up."

systemd_disable: ## Stop booting systemd for this instance (the packages stay installed)
	@$(call systemd_line,false); \
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
	echo "✅ systemd will stop booting with the instance — restart it for that:  .\wsl.ps1 restart"; \
	echo "   The packages stay installed; they do nothing while it is off."
