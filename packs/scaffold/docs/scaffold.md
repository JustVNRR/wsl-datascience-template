# Project Scaffolding, the Pack

[← Back to the README](../../../README.md#optional-tooling)

Making a project: the `fnew` picker, the three gmake targets it delegates to,
the `.env` every project wants, and the one line a pack declares so that its own
step follows the copy. It used to live in the python pack, where most of it was
not python.

## What it brings

| Piece | For | Commands |
| :--- | :--- | :--- |
| [uv](https://docs.astral.sh/uv/) | taking the template tools, on demand | `uv`, `uvx` |
| `fnew` | picking a template from the catalogs, then scaffolding it | `fnew` |
| The three targets | the same act, without the picker | `copier_project`, `cruft_project`, `ccds_project` |

uv is the only thing it installs (about 67 MB, or nothing when the python pack
put it there first). The template tools themselves are not installed: `uvx`
takes each one from its cache the first time it runs.

## What it adds to the shell and to gmake

| Page | What it drives |
| :--- | :--- |
| [Project scaffolding](project-setup.md) | `fnew`, the three targets, the catalogs, the three tools |
| [The virtual environment](../../python/docs/venv.md) | the python pack's step — what runs after one of ITS rows |

## The catalogs are the packs'

This pack ships no template list of its own. `fnew` reads the catalog of every
installed pack (`packs/<name>/cheatsheets/templates.tsv`), shows each row with
the pack it was read from, and calls that pack's step once the copy is done —
`SCAFFOLD_AFTER_python := init_venv` is the one that exists today. A pack that
scaffolds java would ship its own rows and declare `SCAFFOLD_AFTER_java`; this
pack would not change.

## Nobody chooses it

`PACK_VISIBLE := no`: it is in no list — not `add_pack`'s, not
`manage_packs`'s checklist, not `gmake packs_list`. The python pack requires it,
so it arrives before it and leaves with the last pack that requires it. What a
pack requires, and what an invisible one is:
[What a pack is](../../../docs/packs.md#two-packs-one-choice).

## Without it

No `fnew` and no `*_project` target: they are not in the menu at all, and the
python pack is not installed either, since it requires this one.
