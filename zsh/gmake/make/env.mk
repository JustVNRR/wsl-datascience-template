# ==============================================================================
# THE ENVIRONMENT FILES
# ==============================================================================
# Two files decide what a gmake target sees: ~/.config/zsh/gmake/.env.global
# for the values shared by every project, and the project's own .env for what
# identifies it. Both are assembled from samples — the socle's own, in the
# folder above this one, and the ones the packs ship beside their modules.
#
# Nothing reads a sample: they are templates, and what gmake loads is the
# filled copy. Two commands below build that copy, and neither ever rewrites a
# line that is already there — a value you set survives the next run, and so
# does a pack you add later. Two more build it the same way, then open it in
# the editor.
#
# They name no pack: they read every sample they find, so the day a pack
# arrives its variables are already covered.
#
# They are the socle's because the file they write is the socle's: this
# Makefile loads .env.global itself, before it reads a single pack, so a pack
# that shipped the command to build it would be a pack gmake cannot start
# without — the one thing no pack may be.
#
# The two env_global targets run from anywhere — the file they write and open
# is machine-wide, and they ask nothing of the directory you stand in: they are
# the targets the location gate must let through, and they say so here rather
# than in the Makefile.
GATE_EXEMPT_GOALS += env_global_enable env_global_manage

# The samples, in the order they are read: the socle's own first — it carries
# the header that explains the file and its rule — then every installed pack's,
# alphabetically, the way `wildcard` sorts them. The socle's two sit outside
# PACKS_DIR, so no sample can be found twice and nothing has to filter one out.
GLOBAL_ENV_SAMPLES := $(THIS_DIR)/env.global.sample $(wildcard $(PACKS_DIR)/*/env.global.sample)
PROJECT_ENV_SAMPLES := $(THIS_DIR)/env.project.sample $(wildcard $(PACKS_DIR)/*/env.project.sample)

env_global_enable: ## Create or complete ~/.config/zsh/gmake/.env.global from the samples
	$(call merge_env_samples,$(THIS_DIR)/.env.global,$(GLOBAL_ENV_SAMPLES))

env_project_enable: ## Create or complete this project's .env from the samples
	$(call merge_env_samples,.env,$(PROJECT_ENV_SAMPLES))

# The same two files, opened instead of assembled: the editor is yours — $EDITOR
# when the shell exports one (nano, or `code --wait` where VS Code is), nano
# otherwise. Each runs its _enable merge first — create or complete, never a
# line rewritten — so the editor never opens on an empty file: one that is not
# there yet is created whole from the samples, header included, and running
# enable first is never something to remember.
env_global_manage: ## Create or complete ~/.config/zsh/gmake/.env.global, then open it in the editor (nano, or $EDITOR)
	$(call merge_env_samples,$(THIS_DIR)/.env.global,$(GLOBAL_ENV_SAMPLES))
	@editor=$${EDITOR:-nano}; $$editor "$(THIS_DIR)/.env.global"

env_project_manage: ## Create or complete this project's .env, then open it in the editor (nano, or $EDITOR)
	$(call merge_env_samples,.env,$(PROJECT_ENV_SAMPLES))
	@editor=$${EDITOR:-nano}; $$editor .env

# Macro 3: create or complete an environment file from the samples, in order.
# Each sample carries its own header, so the assembled file documents itself.
# Nothing is ever *rewritten*: a variable the target already defines is left
# alone, which is what makes the commands safe to re-run. A value you
# filled in survives, and so does a pack you add later.
# And nothing is written from nothing: with no readable sample at all, the
# command says so and stops rather than leave an empty file behind.
#   $(1) the file to write   $(2) the samples to read
define merge_env_samples
	@target=$(1); \
	readable=; \
	for s in $(2); do [ -f "$$s" ] && readable="$$readable $$s"; done; \
	if [ -z "$$readable" ]; then \
		echo "❌ No sample to read: neither the socle nor an installed pack ships one for this file."; \
		echo "   Nothing was written — $$target is unchanged."; \
		exit 1; \
	fi; \
	if [ ! -f "$$target" ]; then \
		echo "📝 Creating $$target from the samples..."; \
		: > "$$target"; \
		for s in $$readable; do cat "$$s" >> "$$target"; done; \
		echo "✏️  Fill in the values you need — each block documents its own."; \
	else \
		added=0; \
		for s in $$readable; do \
			missing=$$(awk -F= 'FNR==NR { if ($$0 ~ /^[A-Za-z_][A-Za-z0-9_]*=/) seen[$$1]=1; next } $$0 ~ /^[A-Za-z_][A-Za-z0-9_]*=/ && !($$1 in seen)' "$$target" "$$s"); \
			[ -z "$$missing" ] && continue; \
			if [ $$added -eq 0 ]; then \
				printf '\n# --- gmake variables added from the samples ---\n' >> "$$target"; \
				added=1; \
			fi; \
			printf '%s\n' "$$missing" >> "$$target"; \
		done; \
		if [ $$added -eq 0 ]; then \
			echo "ℹ️  $$target already defines every gmake variable — nothing to add."; \
		else \
			echo "📝 Added the missing variables to $$target."; \
		fi; \
	fi
endef
