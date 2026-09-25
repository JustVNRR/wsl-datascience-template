# Python

[← Back to the README](../../../README.md#optional-tooling)

Python, its package manager and the scaffolding tools, installed by the `python`
pack and removed with it. The image carries none of it: an instance without this
pack has no `python3` and no `uv` at all, and the shell, the gmake menu and the
cheatsheets are what it runs on.

## What it brings

| Piece | For | Commands |
| :--- | :--- | :--- |
| [uv](https://docs.astral.sh/uv/) | installing Python and the tools, per project | `uv`, `uvx` |
| Python 3 | the interpreter the tools and the projects run on, downloaded by uv | through `uv run` |
| Compiler and headers | building the wheels that ship no compiled version | `gcc`, `g++` |
| [copier](https://copier.readthedocs.io) / [cruft](https://cruft.github.io/cruft/) | creating a project from a template, and keeping it updatable | `copier`, `cruft` |
| [cookiecutter](https://cookiecutter.readthedocs.io) / [ccds](https://cookiecutter-data-science.drivendata.org) | the ancestor, and the current Cookiecutter Data Science scaffold | `cookiecutter`, `ccds` |
| [ruff](https://docs.astral.sh/ruff/) | formatting and linting Python code | `ruff` |

Python itself is **not** the system's: uv downloads its own build under
`~/.local/share/uv/python`, which is what a project's `.venv` points at. Nothing
here is global, so nothing needs a password once the pack is installed.

## Installing and removing it

```powershell
.\wsl.ps1 add_pack      # pick the instance, then python
.\wsl.ps1 remove_pack   # the reverse
```

`remove_pack` takes the compiler, the headers and the tools back, and with them
what apt had pulled in for them. The uv-managed Python builds and the tools'
environments are not apt's, so the pack names them itself when it leaves.
Projects already scaffolded are untouched — their `.venv` will need uv again the
next time the pack is installed.

## Without it

`fnew`, `gmake lint` and the test targets belong to this pack: in an instance
that does not have it, they are not in the menu at all. What the socle keeps is
the shell, Docker and the gmake targets that drive it.
