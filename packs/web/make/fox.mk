# ==============================================================================
# FIREFOX - THE PRIVACY DEFAULTS
# ==============================================================================
# The browser half's targets - two, and they are a switch: what they call is
# bin/fox.sh, where the state is read and the file written, the arrangement
# vpn.mk and the other packs' modules use - a recipe that did the work itself
# is a recipe nobody can read.
#
# They touch one file of the browser's own directory, beside the sound
# preference the install leaves there, and for the same reason: a preference
# written there is a DEFAULT, so it applies to every profile without a name to
# guess, and a value set in about:config still wins. The file is there, or it
# is not - that is the whole state, and `off` leaves the browser as it was.
#
# They run from anywhere: what a browser does with a page is not a project's
# business - the same declaration vpn_status makes in its own module.

GATE_EXEMPT_GOALS += fox_tweak_on fox_tweak_off

# The script, resolved from this module's own path: make/ and bin/ are
# neighbours inside the pack folder, and the pack moves as one folder.
FOX := $(dir $(lastword $(MAKEFILE_LIST)))../bin/fox.sh

fox_tweak_on: ## Apply the pack's privacy defaults to Firefox (every profile)
	@$(FOX) on

fox_tweak_off: ## Take them back out - the browser's own defaults again
	@$(FOX) off
