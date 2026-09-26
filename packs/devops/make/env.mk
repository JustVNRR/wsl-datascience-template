# ==============================================================================
# THE ENVIRONMENT FILES
# ==============================================================================
# Two files decide what a gmake target sees: ~/.config/zsh/gmake/.env.global
# for the values shared by every project, and the project's own .env for what
# identifies it. Both are assembled from samples — the ones the packs ship
# beside their modules.
#
# Nothing reads a sample: they are templates, and what gmake loads is the
# filled copy. The two commands below build that copy, and neither ever
# rewrites a line that is already there — a value you set survives the next
# run, and so does a pack you add later.
#
# They name no pack: they read every sample they find, so the day a pack
# arrives its variables are already covered.
#
# env_global_enable runs from anywhere — it writes a machine-wide file, and
# asks nothing of the directory you stand in. It is the one target of this pack
# the location gate must let through, and it says so here rather than in the
# Makefile: a target declares itself, and the socle names none.
GATE_EXEMPT_GOALS += env_global_enable

# This pack's own folder, read from this file's own path — make leaves the file
# it is reading at the end of MAKEFILE_LIST — so that a rename of the pack
# breaks nothing in here.
PACK_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

# This pack's samples are read FIRST, and the wildcard brings the others after:
# the assembled file opens on the header that explains its rule and what belongs
# in it, and each pack's block follows, documented one folder away in the sample
# it ships. `filter-out` because the wildcard finds this pack too, and a sample
# read twice would land twice in a file created from scratch.
PACK_GLOBAL_SAMPLES := $(PACK_DIR)/env.global.sample $(filter-out $(PACK_DIR)/env.global.sample,$(wildcard $(PACKS_DIR)/*/env.global.sample))
PACK_PROJECT_SAMPLES := $(PACK_DIR)/env.project.sample $(filter-out $(PACK_DIR)/env.project.sample,$(wildcard $(PACKS_DIR)/*/env.project.sample))

env_global_enable: ## Create or complete ~/.config/zsh/gmake/.env.global from the samples
	$(call merge_env_samples,$(THIS_DIR)/.env.global,$(PACK_GLOBAL_SAMPLES))

env_project_enable: ## Create or complete this project's .env from the samples
	$(call merge_env_samples,.env,$(PACK_PROJECT_SAMPLES))

# Macro 3: create or complete an environment file from the samples, in order.
# Each sample carries its own header, so the assembled file documents itself.
# Nothing is ever *rewritten*: a variable the target already defines is left
# alone, which is what makes the two commands safe to re-run. A value you
# filled in survives, and so does a pack you add later.
# And nothing is written from nothing: with no readable sample at all, the
# command says so and stops rather than leave an empty file behind.
#   $(1) the file to write   $(2) the samples to read
define merge_env_samples
	@target=$(1); \
	readable=; \
	for s in $(2); do [ -f "$$s" ] && readable="$$readable $$s"; done; \
	if [ -z "$$readable" ]; then \
		echo "❌ No sample to read: no installed pack ships one for this file."; \
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
