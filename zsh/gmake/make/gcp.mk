# ==============================================================================
# GCP INFRASTRUCTURE & IAM COMMANDS
# ==============================================================================

gcp_project_list: ## List all GCP projects available to your account
	@echo "📋 Listing GCP projects..."
	gcloud projects list
	# Useful alternatives:
	# gcloud projects list --format="value(projectId)" # lists only IDs
	# gcloud config get-value project # shows only the active project ID

gcp_enable_compute: ## Enable the Compute Engine API for the project
	$(call check_vars, GCP_PROJECT)
	$(call confirm_action, Activation de l'API Compute Engine, GCP_PROJECT)
	@echo "⚙️ Enabling Compute Engine API..."
	gcloud services enable compute.googleapis.com --project=$(GCP_PROJECT)

gcp_enable_storage: ## Enable the Cloud Storage API for the project
	$(call check_vars, GCP_PROJECT)
	$(call confirm_action, Activation de l'API Cloud Storage, GCP_PROJECT)
	@echo "⚙️ Enabling Cloud Storage API..."
	gcloud services enable storage.googleapis.com --project=$(GCP_PROJECT)

gcp_enable_bigquery: ## Enable the BigQuery API for the project
	$(call check_vars, GCP_PROJECT)
	$(call confirm_action, Activation de l'API BigQuery, GCP_PROJECT)
	@echo "⚙️ Enabling BigQuery API..."
	gcloud services enable bigquery.googleapis.com --project=$(GCP_PROJECT)

gcp_enable_cloudrun: ## Enable the Cloud Run API for the project
	$(call check_vars, GCP_PROJECT)
	$(call confirm_action, Activation de l'API Cloud Run, GCP_PROJECT)
	@echo "⚙️ Enabling Cloud Run API..."
	gcloud services enable run.googleapis.com --project=$(GCP_PROJECT)

gcp_enable_artifact_registry: ## Enable the Artifact Registry API for the project
	$(call check_vars, GCP_PROJECT)
	$(call confirm_action, Activation de l'API Artifact Registry, GCP_PROJECT)
	@echo "⚙️ Enabling Artifact Registry API..."
	gcloud services enable artifactregistry.googleapis.com --project=$(GCP_PROJECT)

gcp_enable_apis: ## Enable every API the gmake modules use (the five above at once)
	$(call check_vars, GCP_PROJECT)
	$(call confirm_action, Activation de toutes les APIs du template, GCP_PROJECT)
	@echo "⚙️ Enabling all template APIs (compute, storage, BigQuery, Cloud Run, Artifact Registry)..."
	gcloud services enable \
		compute.googleapis.com \
		storage.googleapis.com \
		bigquery.googleapis.com \
		run.googleapis.com \
		artifactregistry.googleapis.com \
		--project=$(GCP_PROJECT)

gcs_list_buckets: ## List all Cloud Storage buckets in the project
	$(call check_vars, GCP_PROJECT)
	@echo "🪣 Listing Cloud Storage buckets..."
	gcloud storage ls --project=$(GCP_PROJECT)

gcs_create_bucket: ## Create a new Cloud Storage bucket
	$(call check_vars, BUCKET_NAME GCP_REGION GCP_PROJECT)
	$(call confirm_action, Création d'un Bucket Cloud Storage, BUCKET_NAME GCP_REGION GCP_PROJECT)
	@echo "🪣 Creating bucket gs://$(BUCKET_NAME)..."
	gcloud storage buckets create gs://$(BUCKET_NAME) \
		--location=$(GCP_REGION) \
		--project=$(GCP_PROJECT)

gcs_delete_bucket: ## Delete the Cloud Storage bucket and all its contents
	$(call check_vars, BUCKET_NAME)
	$(call confirm_action, Suppression DÉFINITIVE du Bucket et de son contenu, BUCKET_NAME)
	@echo "💣 Deleting bucket gs://$(BUCKET_NAME)..."
	gcloud storage rm --recursive gs://$(BUCKET_NAME)

iam_setup_service_account: ## Create the Service Account and assign IAM roles
	$(call check_vars, SA_NAME GCP_PROJECT SA_EMAIL)
	$(call confirm_action, Création du Service Account et attribution des droits IAM, SA_NAME SA_EMAIL GCP_PROJECT)
	@echo "🤖 Creating or verifying Service Account..."
	gcloud iam service-accounts create $(SA_NAME) \
		--display-name="VM service account" \
		--project=$(GCP_PROJECT) || true
	@echo "🔐 Adding BigQuery Data Editor role..."
	gcloud projects add-iam-policy-binding $(GCP_PROJECT) \
		--member="serviceAccount:$(SA_EMAIL)" \
		--role="roles/bigquery.dataEditor" \
		--quiet
	@echo "🔐 Adding Cloud Storage Object Admin role..."
	gcloud projects add-iam-policy-binding $(GCP_PROJECT) \
		--member="serviceAccount:$(SA_EMAIL)" \
		--role="roles/storage.objectAdmin" \
		--quiet
