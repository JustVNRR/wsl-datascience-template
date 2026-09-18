# ==========================================
# OPTIONAL TOOLING — THE WAY IN
# ==========================================
# requires: !gcloud
#
# Offered only while the CLI is missing. The way out is its own file
# (uninstall_commands.sh), for the same reason the make targets are two files:
# a sheet that is read is a sheet that is shown, so each face needs a file of
# its own rather than a condition inside one.

gmake gcp_install                            # Install the Google Cloud CLI (adds the Google Cloud commands to gmake)
