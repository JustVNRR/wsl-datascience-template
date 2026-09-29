# ==============================================================================
# CLAUDE CODE
# ==============================================================================
# The pack's targets. One line each, calling bin/claude.sh, where the reading,
# the deciding and the wording live - the arrangement web's tunnel uses, and for
# the same reason: a recipe that did the work itself is a recipe nobody can read.
#
# What a target may run, and where it may run from, is the socle's business and
# this file's only declaration: GATE_EXEMPT_GOALS, read by the location gate in
# the Makefile after every module is loaded - which is why the declaration has to
# be here, beside the targets it names, and why the socle names no target of a
# pack in either list.
#
# Exempt, all three, because which provider an instance talks to is not a
# project's business: the questions are asked from wherever you stand, and the
# gate would otherwise refuse them from ~/projects - the same declaration
# vpn_status makes in its own module.

GATE_EXEMPT_GOALS += claude_status claude_profile claude_edit_profiles

# The script, resolved from this module's own path: make/ and bin/ are neighbours
# inside the pack folder, and the pack moves as one folder.
CLAUDE := $(dir $(lastword $(MAKEFILE_LIST)))../bin/claude.sh

# A provider named on the command line - `gmake claude_profile CLAUDE_PROFILE=glm`
# - applies that one and skips the menu, the way `gmake vpn_up VPN_PROFILE=ch`
# does. Read from the command line only: read from .env.global (origin `file`) it
# would be the value the run is about to write back, and the menu is what a bare
# call is for.
NAMED_PROFILE := $(if $(filter command line,$(origin CLAUDE_PROFILE)),$(CLAUDE_PROFILE))

claude_status: ## Show Claude Code here: version, versions kept, the provider in force
	@$(CLAUDE) status

claude_profile: ## Choose the provider this instance talks to, and apply it
	@$(CLAUDE) profile $(NAMED_PROFILE)

claude_edit_profiles: ## Open the dictionary of providers in the editor (nano, or $EDITOR)
	@$(CLAUDE) edit_profiles
