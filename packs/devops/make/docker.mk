# ==============================================================================
# DOCKER COMMANDS
# ==============================================================================
# The container on your machine: everything that runs on docker alone, and runs
# the same whatever else is installed. The production image is another matter -
# its tag names an Artifact Registry path and pushing it needs the Google CLI -
# so building and pushing it live in the gcp pack's artifact_registry.mk.
#
# Both targets build ONE project: they run from its root, and the three
# variables they check identify it. That is why they are here and not in the
# socle: an instance with no project to build had nothing to do with them.

docker_build_local: ## Build the Docker image locally for testing
	$(call check_vars, DOCKER_BASE_IMAGE PACKAGE_NAME DOCKER_LOCAL_IMAGE)
	@echo "🐳 Building local Docker image $(DOCKER_LOCAL_IMAGE):dev..."
	docker build \
		--build-arg DOCKER_BASE_IMAGE=$(DOCKER_BASE_IMAGE) \
		--build-arg PACKAGE_NAME=$(PACKAGE_NAME) \
		--tag=$(DOCKER_LOCAL_IMAGE):dev .

docker_run_local: ## Run the local Docker container on port 8080
	$(call check_vars, DOCKER_LOCAL_IMAGE)
	@echo "🏃♂️ Running container $(DOCKER_LOCAL_IMAGE):dev..."
	@echo "👉 Go to http://localhost:8080"
	docker run -it -e PORT=8000 -p 8080:8000 $(DOCKER_LOCAL_IMAGE):dev
