# Project Scaffolding

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

Scaffold a new project from a curated catalog of templates, with the virtual
environment and direnv bootstrapped along the way.

## Targets

| Target | Action |
|---|---|
| `copier_project` | Scaffold a project with Copier (the `fnew` picker delegates here) |
| `cruft_project` | Scaffold a project with Cruft / Cookiecutter (the `fnew` picker delegates here) |

Both targets scaffold into `./$(PROJECT_NAME)`, then run `init_venv`, which
auto-detects the project's dependency manifest:

- `uv.lock`, or a `pyproject.toml` with a PEP 621 `[project]` table → `uv sync`
  (creates `.venv`, installs dependencies and the `dev` group by default)
- `requirements.txt` → `uv venv` + `uv pip install` (`requirements_dev.txt`
  too when present)
- no recognized manifest → a bare `uv venv`, with a warning

The bootstrap finishes with the direnv hook: `.envrc` sources
`.venv/bin/activate`, so the environment activates automatically on `cd`
into the project.

## Variables

| Variable | Required | Notes |
|---|---|---|
| `PROJECT_NAME` | yes | Destination directory, created relative to the current directory |
| `PROJECT_TEMPLATE_REPO` | yes | Anything Copier/Cruft accepts (`gh:` shorthand or full git URL) |
| `PROJECT_TEMPLATE_VERSION` | no | Pin a template ref/tag — passed as `--vcs-ref` (Copier) or `--checkout` (Cruft) |

## The `fnew` picker

Type `fnew` anywhere:

```console
$ fnew
# → fuzzy-pick a template from the catalog (description + pinned version shown)
Project name: my-analysis
📁 Creating project in: /home/you/projects/my-analysis
🏗️  Scaffolding project with Copier...
🎤 ...then answer the template's own questions (repo name, description...)...
🐍 uv project detected (uv.lock or [project] table) — running uv sync...
🪄 Configuring direnv...
✅ Project my-analysis ready!
```

The destination directory is always displayed and must be confirmed when you
launch `fnew` outside `~/projects`.

## The catalog

The catalog lives in `cheatsheets/templates.tsv` — one template per line,
tab-separated:

```tsv
# One template per line:  <url> <TAB> <tool> <TAB> <version> <TAB> <description>
gh:owner/python-copier-template-ds	copier		Data Science project template
gh:owner/cookiecutter-data-science	cruft	v1	Community DS template (pinned to v1)
```

The optional `version` column pins a template ref — useful when a template's
default branch targets a different tool. The catalog is re-scanned on every
`fnew` call: add, edit, or remove lines to curate your own shortlist.

## Skipping the picker

```bash
gmake copier_project PROJECT_NAME=my-analysis PROJECT_TEMPLATE_REPO=gh:owner/python-copier-template-ds
gmake cruft_project PROJECT_NAME=my-analysis PROJECT_TEMPLATE_REPO=gh:owner/cookiecutter-data-science PROJECT_TEMPLATE_VERSION=v1
```
