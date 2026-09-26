# ==============================================================================
# PROJECT SCAFFOLDING
# ==============================================================================
# The act: copy a template, finish the copy, and let the pack whose row it came
# from do its part. The tools are taken by uvx at the moment one of them runs,
# so nothing is installed here and nothing is left on the PATH.

# The part every project wants, whatever language it is written in: the .env the
# template's own sample describes. That is all of it - the sample is shaped by
# the template's answers, it is the file the user has to fill in, and it is
# copied once. An existing .env is never touched, and a template that ships no
# sample gets nothing.
#
# What a project needs *besides* that is not generic: the .envrc this writes
# when a template ships none sources a Python venv, so it belongs to the pack
# that has one, together with the `direnv allow` that approves it. A pack with
# no venv writes nothing and approves nothing.
define scaffold_generic_after
	@cd $(PROJECT_NAME) && ( [ -f .env ] || [ ! -f .env.sample ] || { echo "📝 Creating ./.env from the project's .env.sample..."; cp .env.sample .env; } )
endef

# What the pack that curates the row adds after that is declared by that pack,
# beside the macro it names: SCAFFOLD_AFTER_python := init_venv is in the python
# pack's own module. `fnew` reads the declaration off the row it picked and
# names the pack on the make command line; called directly, the target names it
# in TEMPLATE_PACK.
#
# $(call $(VAR)) is a macro whose name comes from a variable, which is the whole
# trick - this file never spells out the name of a pack's step. A pack that
# declares nothing, or a call that names no pack, expands to nothing at all: the
# project is copied, its .env is written, and it is left at that.
scaffold_after = $(if $(SCAFFOLD_AFTER_$(1)),$(call $(SCAFFOLD_AFTER_$(1))))

# ==============================================================================
# THE THREE TARGETS
# ==============================================================================
# Location: these targets only run from ~/projects itself, and the gate that
# enforces it lives in the gmake Makefile. That gate cannot name them itself -
# it has to read this declaration, which is why the names are written here,
# beside the targets they name. The socle names no target of a pack: a target
# nobody declares is treated as an ordinary one, and would be refused from
# ~/projects with a message about a project root that is not the point.
SCAFFOLD_GOALS += copier_project cruft_project ccds_project

copier_project: ## Scaffold a project with Copier from ~/projects (fnew picker)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with Copier..."
	@uvx --from copier copier copy $(COPIER_REF_ARG) $(PROJECT_TEMPLATE_REPO) ./$(PROJECT_NAME)
	$(call scaffold_generic_after)
	$(call scaffold_after,$(TEMPLATE_PACK))
	@echo "✅ Project ready in $(PROJECT_NAME)/"

# Optional pinned template ref/tag: --vcs-ref for Copier, --checkout for Cruft
COPIER_REF_ARG = $(if $(PROJECT_TEMPLATE_VERSION),--vcs-ref $(PROJECT_TEMPLATE_VERSION),)
CHECKOUT_ARG = $(if $(PROJECT_TEMPLATE_VERSION),--checkout $(PROJECT_TEMPLATE_VERSION),)

cruft_project: ## Scaffold a project with Cruft/Cookiecutter from ~/projects (fnew picker)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with Cruft..."
	@uvx --from cruft cruft create $(PROJECT_TEMPLATE_REPO) $(CHECKOUT_ARG) --extra-context '{"project_name": "$(PROJECT_NAME)", "repo_name": "$(PROJECT_NAME)"}'
	$(call scaffold_generic_after)
	$(call scaffold_after,$(TEMPLATE_PACK))
	@echo "✅ Project ready in $(PROJECT_NAME)/"

# The `ccds` CLI (cookiecutter-data-science v2) wants its extra context as
# key=value AFTER the template argument, and it asks before running the
# template's hooks - --accept-hooks yes keeps it non-interactive, like copier
# and cruft, which run hooks without asking.
# repo_name is passed explicitly: the template derives it from project_name by
# lowercasing, so a name with an uppercase letter would generate a directory
# that the after-copy step then cannot find.
# The package is `cookiecutter-data-science`; `ccds` is the command inside it,
# and the one uvx has to be told to look for.
ccds_project: ## Scaffold a project with CCDS v2 from ~/projects (fnew picker)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with ccds..."
	@uvx --from cookiecutter-data-science ccds --accept-hooks yes $(CHECKOUT_ARG) -o . $(PROJECT_TEMPLATE_REPO) project_name=$(PROJECT_NAME) repo_name=$(PROJECT_NAME)
	$(call scaffold_generic_after)
	$(call scaffold_after,$(TEMPLATE_PACK))
	@echo "✅ Project ready in $(PROJECT_NAME)/"
