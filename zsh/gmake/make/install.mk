# ==============================================================================
# OPTIONAL TOOLING - THE WAY IN
# ==============================================================================
# This module is loaded only when the Google Cloud CLI is absent: it is the
# counterpart of the five gated modules, and it is a file of its own for the
# reason given in section 5 of global_makefile.mk - the menu reads the text of
# the files make loaded, so a conditional inside a file would show both faces
# at once. The way out (gcp_uninstall) lives in gcp.mk, which is loaded only
# when the CLI is there.

# The Google APT repository (signing key + sources.list.d) ships in the image:
# a few kilobytes. Only the package is left out, so this target is the package
# and nothing else - no repository to configure at runtime.
gcp_install: ## Install the Google Cloud CLI (adds the GCP targets to gmake)
	$(call confirm_action,Install the Google Cloud CLI (~409 MB installed))
	@sudo apt-get update && sudo apt-get install -y --no-install-recommends google-cloud-cli
	@echo "✅ Google Cloud CLI installed."
	@echo "   The Google Cloud commands are in the gmake menu now."
	@echo "   Next: gmake gcp_auth_cli (signs the CLI in to your Google account)."
