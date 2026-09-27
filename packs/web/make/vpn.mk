# ==============================================================================
# THE TUNNEL (WIREGUARD)
# ==============================================================================
# The targets of the pack's other half. Each one is a line calling
# bin/vpn.sh, where the menus and the decisions live: a recipe that opened a menu
# itself would be a recipe nobody can read, and the same script is what the boot
# hook runs when the distro starts.
#
# They run from anywhere: a tunnel is not a project's business, and the location
# gate would otherwise refuse them from ~/projects. That is what
# GATE_EXEMPT_GOALS is for - the same declaration env_global_enable makes in
# make/env.mk, next to the gate it feeds.
#
# The profile can be named on the command line - `gmake vpn_up VPN_PROFILE=ch` -
# which skips the menu. Without it, the menu asks.

GATE_EXEMPT_GOALS += vpn_status vpn_up vpn_down vpn_server vpn_auto_on vpn_auto_off \
                     vpn_profile_add vpn_profile_remove

# The script, resolved from this module's own path: make/ and bin/ are
# neighbours inside the pack folder, and the pack moves as one folder.
VPN := $(dir $(lastword $(MAKEFILE_LIST)))../bin/vpn.sh

vpn_status: ## Show the tunnel, the DNS, the exit IP and what starts with the distro
	@$(VPN) status

vpn_up: ## Connect now - pick the server when no profile is named
	@$(VPN) up $(VPN_PROFILE)

vpn_down: ## Disconnect
	@$(VPN) down

vpn_server: ## Choose the server the distro starts with, and switch to it now
	@$(VPN) server $(VPN_PROFILE)

vpn_auto_on: ## Bring the tunnel up when the distro starts
	@$(VPN) auto on $(VPN_PROFILE)

vpn_auto_off: ## Stop bringing it up with the distro
	@$(VPN) auto off

# Adding one starts from the pack's sample and opens the editor on it. Removing
# one deletes a file that carries a private key, so it is the only target here
# that asks first - the banner and the question are the socle's macro, the same
# one every pack uses before touching something. The script does the work and
# asks nothing itself.
vpn_profile_add: ## Create a profile from the sample, and open the editor on it
	$(call check_vars,VPN_PROFILE)
	@$(VPN) profile_add $(VPN_PROFILE)

vpn_profile_remove: ## Delete a profile - the file that carries your private key
	$(call check_vars,VPN_PROFILE)
	$(call confirm_action,Delete the WireGuard profile $(VPN_PROFILE),VPN_PROFILE)
	@$(VPN) profile_remove $(VPN_PROFILE)
