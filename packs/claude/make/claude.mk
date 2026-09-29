# ==============================================================================
# CLAUDE CODE
# ==============================================================================
# The pack's targets. One line each, calling bin/claude.sh, where the reading
# and the wording live - the arrangement web's tunnel uses, and for the same
# reason: a recipe that did the work itself is a recipe nobody can read.
#
# What a target may run, and where it may run from, is the socle's business and
# this file's only declaration: GATE_EXEMPT_GOALS, read by the location gate in
# the Makefile after every module is loaded - which is why the declaration has
# to be here, beside the targets it names, and why the socle names no target of
# a pack in either list.
#
# Exempt, because what this instance has installed is not a project's business:
# the question "what is on this machine?" is asked from wherever you stand, and
# the gate would otherwise refuse it from ~/projects - the same declaration
# vpn_status makes in its own module.

GATE_EXEMPT_GOALS += claude_status

# The script, resolved from this module's own path: make/ and bin/ are
# neighbours inside the pack folder, and the pack moves as one folder.
CLAUDE := $(dir $(lastword $(MAKEFILE_LIST)))../bin/claude.sh

claude_status: ## Show the Claude Code of this instance: version, versions kept, the login
	@$(CLAUDE) status
