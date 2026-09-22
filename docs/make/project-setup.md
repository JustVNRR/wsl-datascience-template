# Project Scaffolding

[← Back to the README](../../README.md#mlops-makefile-gmake)

Scaffold a new project from a curated catalog of templates, with the virtual
environment and direnv bootstrapped along the way.

## Targets

| Target | Action |
|---|---|
| `copier_project` | Scaffold a project with Copier, from `~/projects` only (the `fnew` picker delegates here) |
| `cruft_project` | Scaffold a project with Cruft / Cookiecutter, from `~/projects` only (the `fnew` picker delegates here) |
| `ccds_project` | Scaffold a project with the `ccds` CLI (Cookiecutter Data Science v2), from `~/projects` only (the `fnew` picker delegates here) |

All three targets only run from `~/projects` itself and scaffold into
`./$(PROJECT_NAME)`, then run `init_venv`, which
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
| `PROJECT_TEMPLATE_VERSION` | no | Pin a template ref/tag — passed as `--vcs-ref` (Copier) or `--checkout` (Cruft and ccds) |

## The `fnew` picker

Type `fnew` anywhere:

```console
$ fnew
# → fuzzy-pick a template from the catalog (description + pinned version shown)
Project folder: my-analysis
📁 Creating project in: /home/you/projects/my-analysis
🏗️  Scaffolding project with Copier...
🎤 ...then answer the template's own questions (repo name, description...)...
🐍 uv project detected (uv.lock or [project] table) — running uv sync...
🪄 Configuring direnv...
✅ Project my-analysis ready!
```

`fnew` only runs from `~/projects` itself — it refuses anywhere else, and so
do the three targets it delegates to.

## Trying a template without adding it

A template does not have to be in the catalog to be used:

```bash
cd ~/projects
fnew gh:owner/repo            # Copier by default
fnew gh:owner/repo cruft      # ...or Cruft, for a cookiecutter template
fnew gh:owner/repo ccds       # ...or the ccds CLI (cookiecutter-data-science v2)
fnew gh:owner/repo cruft v1   # ...pinned to a ref
```

This path reads and writes nothing. A template that turns out not to suit you
costs only the project directory you just created — there is no catalog entry
to clean up afterwards. Use it first: how a template behaves is hard to judge
from its README, and you only find out by scaffolding with it.

The ref is not optional decoration: without it a template is taken from its
**default branch**, which is not always what you want. Cookiecutter Data
Science is the case to know. Its default branch carries the `ccds` scaffold;
the plain cookiecutter template lives on the `v1` tag, deprecated by its own
maintainers but still updatable with `cruft`. One repository, two entries, one
per tool — and neither works with the other's.

## The catalog

The catalog (`cheatsheets/templates.tsv`) is the short list of templates worth
keeping: one per line, tab-separated.

An entry belongs there when a **checkable fact** justifies it:

- the project is maintained (recent release or commits);
- an identifiable owner answers for it (an organisation, rather than an
  anonymous account);
- its CI creates and tests a real project — the strongest signal, and the one
  that separates a maintained template from someone's personal folder.

Popularity alone is not one of those facts: the most starred cookiecutter
template for data science is also one of the oldest, and star counts never go
down. Write the fact in the description column, so the next reader knows why
the line is there.

The optional `version` column pins a template ref — useful when a template's
default branch targets a different tool.

### The three tools

They are not interchangeable, and one repository can appear once per tool:

| Tool | What it runs | Worth knowing |
| :--- | :--- | :--- |
| `copier` | `copier copy` | stores your answers in `.copier-answers.yml`, so `copier update` can replay them |
| `cruft` | `cruft create` | cookiecutter-based; `cruft update` keeps a generated project in step with its template |
| `ccds` | the `ccds` command | the current Cookiecutter Data Science scaffold, on a branch that is no longer a plain cookiecutter template |

The tool column decides which `gmake` target runs: a template that only exists
as a cookiecutter template cannot be scaffolded with `copier`, and the reverse
is true too. When the same repository appears twice, the descriptions say why.

### Where they come from

One family, not three rivals. **Cookiecutter** came first (2013): a template is
a git repository holding a `cookiecutter.json` and files with
`{{ cookiecutter.project_name }}` holes in them. It asks its questions, writes
the project, and stops there — it has no way to update a project it already
generated. Everything else is that idea plus something:

- `cruft` runs the cookiecutter engine (the library ships inside it) and records
  what it generated in `.cruft.json`, which is what makes `cruft update`
  possible later;
- `ccds` is cookiecutter plus the DrivenData template and its own questions;
- `copier` is a separate implementation of the same idea, not built on
  cookiecutter, with conventions of its own.

The `cookiecutter` command is installed as well, so a template whose README
tells you to run it works as written. `cruft create` does the same thing — and
leaves a `.cruft.json` behind, which you may not want for a one-off.

### Adding a line

`fnew` ignores any line that is not four tab-separated columns, and says so on
stderr — a row typed with spaces would otherwise simply never appear in the
picker, which looks exactly like an empty catalog. The safe way to append one
is a `printf` with an explicit `\t`, which cannot turn into spaces:

```bash
printf '%s\t%s\t%s\t%s\n' \
  'gh:owner/repo' 'copier' '' 'What it is (and the fact that justifies it)' \
  >> ~/.config/zsh/cheatsheets/templates.tsv
```

That writes to the copy inside the distro, which is redeployed from
`zsh/cheatsheets/templates.tsv` at build time. An entry meant to survive a
rebuild therefore belongs in the repository — same rule as everything else
under `zsh/`.

## Skipping the picker

```bash
gmake copier_project PROJECT_NAME=my-analysis PROJECT_TEMPLATE_REPO=gh:owner/python-copier-template-ds
gmake cruft_project PROJECT_NAME=my-analysis PROJECT_TEMPLATE_REPO=gh:owner/cookiecutter-data-science PROJECT_TEMPLATE_VERSION=v1
```
