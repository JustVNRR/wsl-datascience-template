# ==============================================================================
# THE TUNNEL (WIREGUARD)
# ==============================================================================
# The targets of the pack's other half. Each one is a line calling bin/vpn.sh,
# where the menus and the decisions live: a recipe that opened a menu itself would
# be a recipe nobody can read, and the same script is what the boot hook runs when
# the distro starts.
#
# They run from anywhere: a tunnel is not a project's business, and the location
# gate would otherwise refuse them from ~/projects. That is what GATE_EXEMPT_GOALS
# is for - the same declaration env_global_enable makes in make/env.mk, next to
# the gate it feeds.
#
# The server is an id in ~/.config/vpn/servers.json, and which one is used is
# VPN_PROFILE, in .env.global - which this file loads, like any other target's
# variables. Naming it on the command line still works, and skips the menu:
# `gmake vpn_up VPN_PROFILE=ch`.

GATE_EXEMPT_GOALS += vpn_status vpn_up vpn_up_from_list vpn_down vpn_server \
                     vpn_ks_on vpn_ks_off vpn_auto_on vpn_auto_off vpn_edit_profiles

# The script, resolved from this module's own path: make/ and bin/ are neighbours
# inside the pack folder, and the pack moves as one folder.
VPN := $(dir $(lastword $(MAKEFILE_LIST)))../bin/vpn.sh

# A server named on the command line - `gmake vpn_server VPN_PROFILE=ch`. Read
# from .env.global (origin `file`), the value is the one the target is about to
# write into that same file: asking it back would only ever answer "already that
# one", and the menu is what a bare call is for.
NAMED_SERVER := $(if $(filter command line,$(origin VPN_PROFILE)),$(VPN_PROFILE))

vpn_status: ## Show the tunnel, the server, the kill switch, the DNS and the exit IP
	@$(VPN) status

vpn_up: ## Connect now - with the server VPN_PROFILE names, or the one you name
	@$(VPN) up $(VPN_PROFILE)

vpn_up_from_list: ## Connect now, picking the server from the JSON in a menu
	@$(VPN) up_from_list

vpn_down: ## Disconnect
	@$(VPN) down

vpn_server: ## Choose the server the distro starts with, and switch to it now
	@$(VPN) server $(NAMED_SERVER)

vpn_ks_on: ## Put the kill switch in the tunnel, and remount it
	@$(VPN) kill_switch on

vpn_ks_off: ## Take the kill switch out of the tunnel, and remount it
	@$(VPN) kill_switch off

vpn_auto_on: ## Bring the tunnel up when the distro starts
	@$(VPN) auto on

vpn_auto_off: ## Stop bringing it up with the distro
	@$(VPN) auto off

vpn_edit_profiles: ## Open the JSON of servers in the editor (nano, or $EDITOR)
	@$(VPN) edit_profiles
