# ==============================================================================
# PROJECT SCAFFOLDING
# ==============================================================================
# The act: copy a template, finish the copy, and let the pack whose row it came
# from do its part. The tools are taken by uvx at the moment one of them runs,
# so nothing is installed here and nothing is left on the PATH.
#
# One tool is read from the image instead, because nothing else can do its job:
# rlwrap. Two of the three ask their questions through cookiecutter, which reads
# a plain line with no editor loaded in the process — the terminal is all there
# is, and the bytes an arrow key sends land in the answer. rlwrap is that
# editor, put in front of the command: it reads the keys, edits the line, and
# hands the finished answer over. copier is left bare: questionary, over
# prompt-toolkit, is a line editor of its own, so wrapping it would add a layer
# to a prompt that already edits.
#
# No test for a terminal here: rlwrap makes that one itself, and better than a
# test could - measured in a pipe, it hands the answer over untouched and exits
# 0, so the CI and the pipes read exactly as they did before. What this variable
# guards is the other case: an instance that has not installed rlwrap yet (an
# older distro, a machine where the image's package is missing). There the name
# is empty, the commands run plain, and the only thing lost is the editing.
RLWRAP := $(shell command -v rlwrap 2>/dev/null)

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
SCAFFOLD_GOALS += copier_project cruft_project ccds_project finish_scaffold

copier_project: ## Scaffold a project with Copier from ~/projects (fnew picker)
	$(call check_vars, PROJECT_NAME PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with Copier..."
	@uvx -q --from copier copier copy $(COPIER_REF_ARG) $(PROJECT_TEMPLATE_REPO) ./$(PROJECT_NAME)
	$(call scaffold_generic_after)
	$(call scaffold_after,$(TEMPLATE_PACK))
	@echo "✅ Project ready in $(PROJECT_NAME)/"

# Optional pinned template ref/tag: --vcs-ref for Copier, --checkout for Cruft
COPIER_REF_ARG = $(if $(PROJECT_TEMPLATE_VERSION),--vcs-ref $(PROJECT_TEMPLATE_VERSION),)
CHECKOUT_ARG = $(if $(PROJECT_TEMPLATE_VERSION),--checkout $(PROJECT_TEMPLATE_VERSION),)

cruft_project: ## Scaffold a project with Cruft/Cookiecutter from ~/projects (fnew picker)
	$(call check_vars, PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with Cruft..."
	@$(RLWRAP) uvx -q --from cruft cruft create $(PROJECT_TEMPLATE_REPO) $(CHECKOUT_ARG)
	CREATED_DIR=$$(command ls -td -- */ | head -n 1 | tr -d '/'); \
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) finish_scaffold PROJECT_NAME="$$CREATED_DIR" TEMPLATE_PACK=$(TEMPLATE_PACK)

# The `ccds` CLI (cookiecutter-data-science v2) asks for project_name and
# repo_name itself, so neither is passed: its question is the only place the
# name is asked, and the directory it creates is then found the same way
# cruft's is. It also asks before running the template's hooks - --accept-hooks
# yes answers that one, like copier and cruft, which run hooks without asking.
# The package is `cookiecutter-data-science`; `ccds` is the command inside it,
# and the one uvx has to be told to look for.
ccds_project: ## Scaffold a project with CCDS v2 from ~/projects (fnew picker)
	$(call check_vars, PROJECT_TEMPLATE_REPO)
	@echo "🏗️  Scaffolding project with ccds..."
	@$(RLWRAP) uvx -q --from cookiecutter-data-science ccds --accept-hooks yes $(CHECKOUT_ARG) -o . $(PROJECT_TEMPLATE_REPO)
	CREATED_DIR=$$(command ls -td -- */ | head -n 1 | tr -d '/'); \
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) finish_scaffold PROJECT_NAME="$$CREATED_DIR" TEMPLATE_PACK=$(TEMPLATE_PACK)

# The step that follows a copy, for the two tools that create the folder
# themselves: the target above hands it the name it just found. Called with no
# name at all - the target typed by hand, or a template that created nothing -
# every step below would `cd` with no argument, which is $HOME: the venv would
# land in the person's own directory instead of a project's. So it refuses,
# rather than do the wrong thing quietly.
finish_scaffold:
	@[ -n "$(PROJECT_NAME)" ] || { echo "❌ No folder to finish — nothing was created, and nothing was done."; exit 1; }
	$(call scaffold_generic_after)
	$(call scaffold_after,$(TEMPLATE_PACK))
	@echo "✅ Project ready in $(PROJECT_NAME)/"
