# ==============================================================================
# COMPUTE ENGINE (VM) COMMANDS
# ==============================================================================

vm_create: ## Create the VM (run iam_setup_service_account first if it needs GCP API access)
	$(call check_vars, INSTANCE GCP_PROJECT ZONE IMAGE_FAMILY IMAGE_PROJECT MACHINE_TYPE SA_EMAIL)
	$(call confirm_action, Création de la Machine Virtuelle (Facturée), INSTANCE GCP_PROJECT ZONE MACHINE_TYPE)
	@echo "🖥️ Creating VM $(INSTANCE) with service account $(SA_EMAIL)..."
	gcloud compute instances create $(INSTANCE) \
		--project=$(GCP_PROJECT) \
		--zone=$(ZONE) \
		--image-family=$(IMAGE_FAMILY) \
		--image-project=$(IMAGE_PROJECT) \
		--machine-type=$(MACHINE_TYPE) \
		--service-account=$(SA_EMAIL) \
		--scopes=https://www.googleapis.com/auth/cloud-platform

vm_setup: ## Send and execute the setup script on the VM
	$(call check_vars, INSTANCE GCP_PROJECT ZONE PYTHON_VERSION VENV_NAME)
	$(call confirm_action, Exécution du script d'installation sur la VM, INSTANCE GCP_PROJECT PYTHON_VERSION)
	@echo "📦 Sending setup script to VM..."
	gcloud compute scp scripts/setup_vm.sh $(INSTANCE):~/ \
		--project=$(GCP_PROJECT) \
		--zone=$(ZONE)
	@echo "⚙️ Executing script on the VM..."
	gcloud compute ssh $(INSTANCE) \
		--project=$(GCP_PROJECT) \
		--zone=$(ZONE) \
		--command="bash ~/setup_vm.sh $(PYTHON_VERSION) $(VENV_NAME)"
	@echo "🗑️ Cleaning up script on the VM..."
	gcloud compute ssh $(INSTANCE) \
		--project=$(GCP_PROJECT) \
		--zone=$(ZONE) \
		--command="rm ~/setup_vm.sh"

vm_connect: ## Connect to the VM via SSH with agent forwarding
	$(call check_vars, INSTANCE GCP_PROJECT ZONE)
	@echo "🔌 Connecting to $(INSTANCE)..."
	gcloud compute ssh $(INSTANCE) --project=$(GCP_PROJECT) --zone=$(ZONE) --ssh-flag="-A"

vm_start: ## Start the virtual machine (CPU billing resumes)
	$(call check_vars, INSTANCE GCP_PROJECT ZONE)
	@echo "🟢 Starting machine $(INSTANCE)..."
	gcloud compute instances start $(INSTANCE) \
		--project=$(GCP_PROJECT) \
		--zone=$(ZONE)

vm_stop: ## Stop the virtual machine (Save CPU billing)
	$(call check_vars, INSTANCE GCP_PROJECT ZONE)
	@echo "🔴 Stopping machine $(INSTANCE)... (CPU is no longer billed)"
	gcloud compute instances stop $(INSTANCE) \
		--project=$(GCP_PROJECT) \
		--zone=$(ZONE)

vm_delete: ## Delete the virtual machine permanently
	$(call check_vars, INSTANCE GCP_PROJECT ZONE)
	$(call confirm_action, Suppression DÉFINITIVE de la Machine Virtuelle, INSTANCE GCP_PROJECT ZONE)
	@echo "💣 Deleting machine $(INSTANCE) permanently..."
	gcloud compute instances delete $(INSTANCE) \
		--project=$(GCP_PROJECT) \
		--zone=$(ZONE) \
		--quiet
