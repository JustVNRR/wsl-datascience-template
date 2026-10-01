# ==============================================================================
# FIREFOX - THE PRIVACY SETTINGS
# ==============================================================================
# The browser half's manual targets - two, and the sets themselves are what
# the launchers put in place at every launch: `fox` runs the light set, `pfox`
# the strict one (docs/fox.md), through the link the install leaves in the
# browser's directory. The link is why a launch costs no password: it points
# at a file of the user's own, and a set is put in place by replacing that.
#
# So these two are the manual face: `fox_tweak_on` puts the strict set in
# place, and sets the link up if it never was (one sudo, once);
# `fox_tweak_off` takes everything out, the browser stock again. What they
# call is bin/fox.sh - a recipe that did the work itself is a recipe nobody
# can read.
#
# They run from anywhere: what a browser does with a page is not a project's
# business - the same declaration vpn_status makes in its own module.

GATE_EXEMPT_GOALS += fox_tweak_on fox_tweak_off

# The script, resolved from this module's own path: make/ and bin/ are
# neighbours inside the pack folder, and the pack moves as one folder.
FOX := $(dir $(lastword $(MAKEFILE_LIST)))../bin/fox.sh

fox_tweak_on: ## Apply the strict privacy settings (fox/pfox pick a set on their own)
	@$(FOX) on

fox_tweak_off: ## Take the settings out - the browser's own defaults again
	@$(FOX) off
