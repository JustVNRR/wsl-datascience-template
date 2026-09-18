# ==========================================
# PROJECT SCAFFOLDING CHEATSHEET
# ==========================================

fnew                                        # Scaffold a new project: interactively pick a template from the catalog
fnew gh:owner/repo [cruft] [version]        # Scaffold straight from a URL the catalog does not list (reads and writes nothing)
gmake copier_project PROJECT_NAME=<name> PROJECT_TEMPLATE_REPO=<url>  # Scaffold with Copier (skip the picker; from ~/projects only)
gmake cruft_project PROJECT_NAME=<name> PROJECT_TEMPLATE_REPO=<url>   # Scaffold with Cruft/Cookiecutter (skip the picker; from ~/projects only)
gmake ccds_project PROJECT_NAME=<name> PROJECT_TEMPLATE_REPO=<url>    # Scaffold with the ccds CLI, CCDS v2 (skip the picker; from ~/projects only)
