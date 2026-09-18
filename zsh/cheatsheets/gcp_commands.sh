# ==========================================
# GCP ONBOARDING & AUTH CHEATSHEET
# requires: gcloud
# ==========================================
# Raw gcloud commands for the one-time setup — the full walkthrough lives in
# docs/gcp/onboarding.md (make targets live in make_commands.sh)

# --- 1. AUTHENTICATION (once per distro, lost if the distro is recreated) ---
gcloud auth login                              # Login 1: identify YOURSELF to the gcloud/bq tools (everything the global Makefile calls) — browser flow
gcloud auth application-default login          # Login 2: identify YOURSELF to your Python code (google-cloud-* libraries)
gcloud auth list                               # Show which account gcloud is currently using
gcloud auth revoke                             # Revoke the CLI credentials of the current account

# --- 2. PROJECT & BILLING ---
gcloud projects list                           # List the projects your account can access
gcloud config get-value project                # Show the project gcloud considers active (the global Makefile always passes --project explicitly)
gcloud config set project <PROJECT_ID>         # Set the active project for manually-typed gcloud commands
gcloud billing projects describe <PROJECT_ID>  # Check whether billing is enabled on a project

# --- 3. APIS & SERVICE ACCOUNTS ---
gcloud services list --enabled                 # List the APIs already enabled on the active project
gcloud iam service-accounts list               # List the service accounts (robot identities) of the active project
gcloud iam service-accounts keys create <FILE.json> --iam-account=<SA_EMAIL> # Create a JSON key for a service account (the bootcamp file) — treat it as a password
