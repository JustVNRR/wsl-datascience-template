# ==============================================================================
# DOCKER COMMANDS
# ==============================================================================
# The image side of the workflow: everything that runs on docker alone. The
# registry targets that call `gcloud` live in artifact_registry.mk, loaded only
# when the CLI is present.

docker_build_local: ## Build the Docker image locally for testing
	$(call check_vars, DOCKER_BASE_IMAGE PACKAGE_NAME GAR_IMAGE)
	@echo "🐳 Building local Docker image $(GAR_IMAGE):dev..."
	docker build \
		--build-arg DOCKER_BASE_IMAGE=$(DOCKER_BASE_IMAGE) \
		--build-arg PACKAGE_NAME=$(PACKAGE_NAME) \
		--tag=$(GAR_IMAGE):dev .

docker_run_local: ## Run the local Docker container on port 8080
	$(call check_vars, GAR_IMAGE)
	@echo "🏃♂️ Running container $(GAR_IMAGE):dev..."
	@echo "👉 Go to http://localhost:8080"
	docker run -it -e PORT=8000 -p 8080:8000 $(GAR_IMAGE):dev

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
	$(call confirm_action, Push the production image to Artifact Registry, GCP_REGION GCP_PROJECT ARTIFACTSREPO GAR_IMAGE)
	@echo "🚀 Pushing image to Artifact Registry..."
	docker push $(GCP_REGION)-docker.pkg.dev/$(GCP_PROJECT)/$(ARTIFACTSREPO)/$(GAR_IMAGE):prod
