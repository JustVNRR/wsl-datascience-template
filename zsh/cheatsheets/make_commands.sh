# ==========================================
# MAKEFILE CHEATSHEET (via alias gmake)
# ==========================================

# --- 1. GOOGLE CLOUD RUN ---
gmake cloudrun_deploy                        # Deploy container to Google Cloud Run
gmake cloudrun_logs                          # View and stream Cloud Run service logs
gmake cloudrun_list                          # List all active Cloud Run services
gmake cloudrun_url                           # Fetch public URL of the deployed API service
gmake cloudrun_delete                        # Delete Cloud Run service

# --- 2. GOOGLE BIGQUERY ---
gmake bigquery_create_table                  # Create a new table in BigQuery
gmake bigquery_show                          # Inspect table or dataset metadata
gmake bigquery_delete_table                  # Delete a specific table in BigQuery
gmake bigquery_delete_dataset                # Delete an entire dataset and its contents in BigQuery

# --- 3. DOCKER & ARTIFACT REGISTRY ---
gmake docker_build_local                     # Build Docker image for local development environment
gmake docker_run_local                       # Run Docker container locally
gmake artifact_registry_create               # Create repository in Google Artifact Registry
gmake artifact_registry_role                 # Configure IAM permissions for Artifact Registry
gmake docker_auth                            # Authenticate Docker client with Google Cloud credentials
gmake docker_build_prod                      # Build production-optimized Docker image
gmake docker_push_prod                       # Push production image to Artifact Registry

# --- 4. GOOGLE COMPUTE ENGINE (VM) ---
gmake vm_create                              # Provision a new Compute Engine virtual machine
gmake vm_setup                               # Install and configure dependencies on the VM
gmake vm_connect                             # Open an SSH session into the virtual machine
gmake vm_start                               # Start a stopped virtual machine instance
gmake vm_stop                                # Gracefully shut down the virtual machine
gmake vm_delete                              # Permanently terminate and delete the virtual machine

# --- 5. GOOGLE CLOUD PLATFORM (GCP - GENERAL) ---
gmake gcp_project_list                       # List all accessible GCP projects
gmake gcp_enable_compute                     # Enable Compute Engine API for the active project
gmake gcs_list_buckets                       # List all Google Cloud Storage (GCS) buckets
gmake gcs_create_bucket                      # Provision a new Cloud Storage bucket
gmake gcs_delete_bucket                      # Delete a Cloud Storage bucket
gmake iam_setup_service_account              # Create and configure an IAM service account

# --- 6. GITHUB CLI (PULL REQUESTS) ---
gmake gh_pr_create                           # Create a new Pull Request on GitHub
gmake gh_pr_toreview                         # Mark a Pull Request as ready for review
gmake gh_pr_wip                              # Convert a Pull Request back to draft status (WIP)
gmake gh_pr_ls                               # List all open Pull Requests in the repository

# --- 7. LINT (RUFF & SHELLCHECK) ---
gmake lint                                   # Run all lint checks (Python + shell), non-destructive
gmake lint-py                                # Check Python code with ruff (PY_TARGETS="..." to scope)
gmake lint-sh                                # Check shell scripts with shellcheck (SH_TARGETS="..." to scope)
gmake lint-format                            # Auto-fix and format Python code with ruff

# --- 8. TESTS (PYTEST) ---
gmake test                                   # Run the whole test suite
gmake test-fast                              # Run fast tests only, without external infrastructure (CI lane)
gmake test-functional                        # Run functional tests (real local infra needed, e.g. .env, Docker, model)
gmake test-gcp                               # Run tests hitting a real GCP environment (test/staging/prod)
