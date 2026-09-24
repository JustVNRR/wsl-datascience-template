# ==============================================================================
# THE ENVIRONMENT FILES
# ==============================================================================
# Two files decide what a gmake target sees: ~/.config/zsh/gmake/.env.global
# for the values shared by every project, and the project's own .env for what
# identifies it. Both are assembled from samples — the socle's, and the ones
# each pack ships beside its modules.
#
# Nothing reads a sample: they are templates, and what gmake loads is the
# filled copy. The two commands below build that copy, and neither ever
# rewrites a line that is already there — a value you set survives the next
# run, and so does a pack you add later.
#
# They name no pack: they read every sample they find, so the day a pack
# arrives its variables are already covered.

env_global_enable: ## Create or complete ~/.config/zsh/gmake/.env.global from the samples
	$(call merge_env_samples,$(THIS_DIR)/.env.global,$(THIS_DIR)/.env.global.sample $(wildcard $(PACKS_DIR)/*/env.global.sample))

env_project_enable: ## Create or complete this project's .env from the samples
	$(call merge_env_samples,.env,$(THIS_DIR)/.env.project.sample $(wildcard $(PACKS_DIR)/*/env.project.sample))
