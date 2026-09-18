# ==============================================================================
# ARTIFACT REGISTRY
# ==============================================================================
# The Google half of the Docker workflow. It is a module of its own for the
# same reason the four GCP ones are: these targets call `gcloud`, so the module
# is loaded only when it is present (section 5 of global_makefile.mk). What
# needs nothing but docker - building and running images - stays in docker.mk,
# because a module carries one condition, not two.

artifact_registry_create: ## Create the Docker repository in Artifact Registry
	$(call check_vars, ARTIFACTSREPO GCP_REGION GCP_PROJECT)
	$(call confirm_action, Création du dépôt Artifact Registry, ARTIFACTSREPO GCP_REGION GCP_PROJECT)
	@echo "📦 Creating Artifact Registry repository $(ARTIFACTSREPO)..."
	gcloud artifacts repositories create $(ARTIFACTSREPO) \
		--repository-format=docker \
		--location=$(GCP_REGION) \
		--description="Docker repository $(ARTIFACTSREPO) for project $(GCP_PROJECT)" \
		--project=$(GCP_PROJECT) || true

artifact_registry_role: ## Grant yourself permission to push to Artifact Registry
	$(call check_vars, GCP_PROJECT)
	$(call confirm_action, Modification des droits IAM (Artifact Registry Writer), GCP_PROJECT)
	@echo "🔐 Adding Artifact Registry Writer role to your account..."
	gcloud projects add-iam-policy-binding $(GCP_PROJECT) \
		--member="user:$$(gcloud config get-value account)" \
		--role="roles/artifactregistry.writer"

docker_auth: ## Configure Docker to authenticate with Google Cloud
	$(call check_vars, GCP_REGION)
	@echo "🔑 Configuring Docker authentication for GCP..."
	gcloud auth configure-docker $(GCP_REGION)-docker.pkg.dev --quiet
