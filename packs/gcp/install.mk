# ==============================================================================
# OPTIONAL TOOLING - THE WAY IN
# ==============================================================================
# This module is loaded only when the Google Cloud CLI is absent: it is the
# counterpart of the five gated modules, and it is a file of its own for the
# reason given in section 5 of the gmake Makefile - the menu reads the text of
# the files make loaded, so a conditional inside a file would show both faces
# at once. The way out (gcp_uninstall) lives in gcp.mk, which is loaded only
# when the CLI is there.

# The image carries no trace of Google: no signing key, no APT source. This
# target registers both, then installs the package - the four steps any
# third-party install follows: fetch the key, trust it, add the address,
# refresh the catalogue, install. gcp_uninstall undoes exactly that.
# --batch --yes: gpg refuses to overwrite an existing output file without it,
# and the key file survives a removal that stopped halfway.
gcp_install: ## Install the Google Cloud CLI (adds the GCP targets to gmake)
	$(call confirm_action, Install the Google Cloud CLI (~409 MB installed))
	@echo "➕ Registering the Google APT repository..."
	@sudo mkdir -p -m 755 /etc/apt/keyrings
	@curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
		| sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/cloud.google.gpg
	@sudo chmod go+r /etc/apt/keyrings/cloud.google.gpg
	@echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
		| sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null
	@sudo apt-get update
	@sudo apt-get install -y --no-install-recommends google-cloud-cli
	@echo "✅ Google Cloud CLI installed."
	@echo "   The Google Cloud commands are in the gmake menu now."
	@echo "   Next: gmake gcp_auth_cli (signs the CLI in to your Google account)."
