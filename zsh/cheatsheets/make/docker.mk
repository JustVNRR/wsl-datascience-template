# ==============================================================================
# DOCKER & ARTIFACT REGISTRY COMMANDS
# ==============================================================================

docker_build_local: ## Build the Docker image locally for testing
	$(call check_vars, DOCKER_BASE_IMAGE PACKAGE_NAME GAR_IMAGE)
	@echo "🐳 Building local Docker image $(GAR_IMAGE):dev..."
	docker build \
		--build-arg DOCKER_BASE_IMAGE=$(DOCKER_BASE_IMAGE) \
		--build-arg PACKAGE_NAME=$(PACKAGE_NAME) \
		--tag=$(GAR_IMAGE):dev .

docker_run_local: ## Run the local Docker container on port 8080
	$(call check_vars, GAR_IMAGE)
	@echo "🏃‍♂️ Running container $(GAR_IMAGE):dev..."
	@echo "👉 Go to http://localhost:8080"
	docker run -it -e PORT=8000 -p 8080:8000 $(GAR_IMAGE):dev

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

docker_build_prod: ## Build the Docker image for production (linux/amd64)
	$(call check_vars, DOCKER_BASE_IMAGE PACKAGE_NAME GCP_REGION GCP_PROJECT ARTIFACTSREPO GAR_IMAGE)
	@echo "🏗️ Building production image..."
	docker build \
		--platform linux/amd64 \
		--build-arg DOCKER_BASE_IMAGE=$(DOCKER_BASE_IMAGE) \
		--build-arg PACKAGE_NAME=$(PACKAGE_NAME) \
		-t $(GCP_REGION)-docker.pkg.dev/$(GCP_PROJECT)/$(ARTIFACTSREPO)/$(GAR_IMAGE):prod \
		.

docker_push_prod: ## Push the production image to Artifact Registry
	$(call check_vars, GCP_REGION GCP_PROJECT ARTIFACTSREPO GAR_IMAGE)
	$(call confirm_action, Déploiement de l'image de Production, GCP_REGION GCP_PROJECT ARTIFACTSREPO GAR_IMAGE)
	@echo "🚀 Pushing image to Artifact Registry..."
	docker push $(GCP_REGION)-docker.pkg.dev/$(GCP_PROJECT)/$(ARTIFACTSREPO)/$(GAR_IMAGE):prod
