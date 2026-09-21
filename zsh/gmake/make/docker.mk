# ==============================================================================
# DOCKER COMMANDS
# ==============================================================================
# The container on your machine: everything that runs on docker alone, and runs
# the same whatever else is installed. The production image is another matter -
# its tag names an Artifact Registry path and pushing it needs the Google CLI -
# so building and pushing it live in artifact_registry.mk, loaded only when that
# CLI is present.

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
