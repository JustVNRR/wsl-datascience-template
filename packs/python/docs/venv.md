# The Virtual Environment

[← Back to the README](../../../README.md#optional-tooling)

What the python pack does for a project once a template has been copied: create
its virtual environment and install what the project declares.

## Who calls it

The act of scaffolding — the picker, the three `*_project` targets, the
catalog — is the [scaffold pack](../../scaffold/docs/scaffold.md)'s. A pack that
has a step of its own declares it beside the macro it names, and this pack
declares `init_venv`:

```make
SCAFFOLD_AFTER_python := init_venv      # packs/python/make/venv.mk
```

`fnew` reads that declaration off the row it picked: a row from this pack's
catalog runs `init_venv`, a row from another pack's runs that pack's step, and
nothing else runs at all. Called by name, the target takes the pack from
`TEMPLATE_PACK` instead, which this pack sets to `python` in the sample it
ships.

## The three cases

`init_venv` looks at what the template wrote, and exactly one branch installs
dependencies:

| What the project has | What runs |
| :--- | :--- |
| `uv.lock`, or a `pyproject.toml` with a PEP 621 `[project]` table | `uv sync` — creates `.venv`, installs the dependencies and the `dev` group |
| `requirements.txt` | `uv venv`, then `uv pip install` (and `requirements_dev.txt` when present) |
| none of the above | a bare `uv venv`, with a warning — the dependencies are yours to install |

Which Python the project runs on is the project's to say and uv's to serve: the
version its `.python-version` or `requires-python` asks for, taken from uv's own
build when it has it, from the distro's interpreter when that is the one that
matches, and from a download when neither does — the order, and where the pack's
own build fits, are in [Python](python.md#what-it-brings).

## direnv, and the project's activation

The macro ends by making the project usable on the way in:

- **`.envrc`** — written only where the project has none, so the one a template
  ships is left alone. The line it writes sources `.venv/bin/activate` behind a
  guard that keeps it quiet before the first `uv sync`.
- **`direnv allow`** — approves whichever `.envrc` is there, so the environment
  activates on `cd` into the project.

Both are here rather than in the scaffolding act because both are about the
venv: a project with no Python has no venv to activate. The `.env` a template's
sample describes *is* the act's business — it is copied by `scaffold`, for every
project, whatever language it is written in.

## Skipping the picker

```bash
cd ~/projects
gmake copier_project PROJECT_NAME=my-analysis PROJECT_TEMPLATE_REPO=gh:owner/python-copier-template-ds
```

`TEMPLATE_PACK` decides whose step runs after the copy — `python` unless you say
otherwise. `TEMPLATE_PACK=` copies the template, writes the `.env`, and stops
there: no environment, no direnv.
