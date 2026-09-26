# Python

[← Back to the README](../../../README.md#optional-tooling)

Python, its package manager and what a project's environment needs, installed by
the `python` pack and removed with it. The image carries none of it: an instance
without this pack has no `python3` and no `uv` at all, and the shell, the gmake
menu and the cheatsheets are what it runs on.

## What it brings

| Piece | For | Commands |
| :--- | :--- | :--- |
| [uv](https://docs.astral.sh/uv/) | installing Python, and a project's dependencies | `uv`, `uvx` |
| Python 3 | the interpreter the projects run on, downloaded by uv | through `uv run` |
| Compiler and headers | building the wheels that ship no compiled version | `gcc`, `g++` |
| [ruff](https://docs.astral.sh/ruff/) | formatting and linting Python code | `ruff` |

Python itself is **not** the system's, unless a project asks for a version the
distro happens to carry. A `.venv` runs on the version the project asks for
(`.python-version`, `requires-python`), and uv serves it in this order: its own
build when it has that version, the distro's interpreter when that is the one
that matches, a download when neither does. That order is uv's default
(`python-preference` is `managed`: a system python is still preferred over
downloading one). A project that asks for nothing runs on the build this pack
installed — and so do the tools `fnew` drives. Nothing here is global, so
nothing needs a password once the pack is installed.

The tools that create a project — copier, cruft, ccds — are not here: they come
with the `scaffold` pack, which takes each one from uv's cache the day it is
first used. This pack is what a project runs on once it exists.

## What it adds to the shell and to gmake

| Page | What it drives |
| :--- | :--- |
| [The virtual environment](venv.md) | `init_venv`, the step that runs after one of this pack's template rows |
| [Lint](lint.md) | `lint`, `lint-py` (ruff), `lint-sh` (shellcheck), `lint-format` |
| [Tests](tests.md) | `test`, `test-fast`, `test-functional`, `test-gcp` |

The shell side is read from this pack's own folder
(`~/.config/packs/python/zsh/`): uv's PATH and completions. Nothing is copied
into `~/.config/zsh`, so removing the pack takes its commands out of the shell
too.

## Installing and removing it

```powershell
.\wsl.ps1 add_pack      # pick the instance, then python
.\wsl.ps1 remove_pack   # the reverse
```

This pack requires two others, and they arrive with it: `devops`, the targets
that build and ship the projects it makes runnable, and `scaffold`, the act of
creating one. Neither is offered in a list, and both leave with the last pack
that requires them — see [What a pack is](../../../docs/packs.md#two-packs-one-choice).

`remove_pack` takes the compiler, the headers, the interpreter uv downloaded and
ruff back, and with them what apt had pulled in for them. Projects already
scaffolded are untouched — their `.venv` will need uv again the next time the
pack is installed.

## Without it

`gmake lint` and the test targets belong to this pack: in an instance that does
not have it, they are not in the menu at all. `fnew` and the `*_project` targets
are the `scaffold` pack's, and that pack comes with this one — an instance that
has no pack at all runs the shell, and the gmake targets that drive Docker.
