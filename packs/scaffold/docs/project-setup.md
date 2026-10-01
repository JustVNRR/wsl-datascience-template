# Project Scaffolding

[← Back to the README](../../../README.md#optional-tooling)

Create a project from a template: pick one from the catalogs the installed packs
curate, or give a URL. The copy is finished by the pack whose row it came from —
a Python project gets its virtual environment, a project from a pack with no step
of its own is copied and left at that.

## Targets

| Target | Action |
|---|---|
| `copier_project` | Scaffold a project with Copier, from `~/projects` only (the `fnew` picker delegates here) |
| `cruft_project` | Scaffold a project with Cruft / Cookiecutter, from `~/projects` only (the `fnew` picker delegates here) |
| `ccds_project` | Scaffold a project with the `ccds` CLI (Cookiecutter Data Science v2), from `~/projects` only (the `fnew` picker delegates here) |

All three only run from `~/projects` itself. Copier scaffolds into
`./$(PROJECT_NAME)`, the folder it was given; cruft and ccds ask for the name in
their own questions and create the folder themselves, so no name is passed to
them. Then, in this order:

1. **the act's own step**, for every project: the `.env` the template's sample
   describes is copied once — that is the file you have to fill in, and the
   sample is already shaped by the template's answers. A template that ships no
   sample gets nothing, and an existing `.env` is never touched.
2. **the step of the pack the row came from**, declared by that pack in one line
   — `SCAFFOLD_AFTER_python := init_venv` — and called with the pack `fnew`
   reads off the row. Nothing is named in hard here: a pack that declares no
   step, or a call that names no pack, runs nothing at all.

## Variables

| Variable | Required | Notes |
|---|---|---|
| `PROJECT_NAME` | copier only | Destination directory, created relative to the current directory — cruft and ccds ask for the name themselves |
| `PROJECT_TEMPLATE_REPO` | yes | Anything Copier/Cruft accepts (`gh:` shorthand or full git URL) |
| `PROJECT_TEMPLATE_VERSION` | no | Pin a template ref/tag — passed as `--vcs-ref` (Copier) or `--checkout` (Cruft and ccds) |
| `TEMPLATE_PACK` | no | Pack whose step runs once the template is copied (`fnew` passes the row's pack; a direct call reads it from `.env.global`) |

## The `fnew` picker

Type `fnew` from `~/projects`:

```console
$ fnew
# → fuzzy-pick a template (the pack it came from, the tool, the pinned version)
Project folder: my-analysis
📁 Creating project in: /home/you/projects/my-analysis
🏗️  Scaffolding project with Copier...
🎤 ...then answer the template's own questions (repo name, description...)...
📝 Creating ./.env from the project's .env.sample...
🐍 uv project detected (uv.lock or [project] table) — running uv sync...
🪄 Configuring direnv...
✅ Project ready in my-analysis/
```

`Project folder` is asked for Copier alone, and only once: cruft and ccds ask
for the name in their own questions, and `fnew` then steps into the directory
the tool created.

The last three lines are the python pack's — they come from the row's pack, and
a row of another pack replaces them. `fnew` only runs from `~/projects` itself,
and leaves you inside the new project.

## Trying a template without adding it

A template does not have to be in a catalog to be used:

```bash
cd ~/projects
fnew gh:owner/repo            # Copier by default
fnew gh:owner/repo cruft      # ...or Cruft, for a cookiecutter template
fnew gh:owner/repo ccds       # ...or the ccds CLI (cookiecutter-data-science v2)
fnew gh:owner/repo cruft v1   # ...pinned to a ref
```

This path reads and writes nothing: a template that does not suit you costs
only the project directory. It names no pack, so `TEMPLATE_PACK` decides whose
step runs.

Without a ref a template is taken from its **default branch**, which is not
always what you want: Cookiecutter Data Science's carries the `ccds` scaffold,
while the plain cookiecutter template lives on the `v1` tag — one repository,
two entries, one per tool, and neither works with the other's.

## The catalogs

`fnew` reads the catalog of **every installed pack** —
`packs/<name>/cheatsheets/templates.tsv` — and shows each row with the pack it
was read from:

```text
python · copier @9.18.2  |  astral-sh/uv-fastapi  |  FastAPI service
java   · copier          |  spring-guides/gs-boot |  Spring Boot minimal
```

That pack is the one whose step runs once the template is copied, so a row
belongs in the catalog of the pack that knows what to do with the project it
produces. This pack ships no catalog of its own: it reads the others'.

An entry belongs there when a **checkable fact** justifies it — the project is
maintained, an identifiable owner answers for it, its CI creates and tests a
real project — and the description column says which. Popularity alone is not
one of those facts: star counts never go down.

The optional `version` column pins a template ref — useful when a template's
default branch targets a different tool.

### The three tools

They are not installed: `uvx --from <package> <command>` takes each one from
uv's cache the first time it runs, and a tool that is never used costs nothing.
Nothing of them is on your PATH either — what `uvx` fetched cannot shadow a
command of your own.

They are not interchangeable, and one repository can appear once per tool:

| Tool | What it runs | Worth knowing |
| :--- | :--- | :--- |
| `copier` | `copier copy` | stores your answers in `.copier-answers.yml`, so `copier update` can replay them |
| `cruft` | `cruft create` | cookiecutter-based; `cruft update` keeps a generated project in step with its template |
| `ccds` | the `ccds` command | the current Cookiecutter Data Science scaffold, on a branch that is no longer a plain cookiecutter template |

The tool column decides which `gmake` target runs: a template that only exists
as a cookiecutter template cannot be scaffolded with `copier`, and the reverse
is true too. When the same repository appears twice, the descriptions say why.

Only one of the three can edit an answer on its own: `copier` asks through a
line editor (questionary), so the arrows work while you answer. `cruft` and
`ccds` ask through cookiecutter, which reads a plain line — an arrow key lands
in the answer as the bytes it sends.

So the two of them run under `rlwrap`, which is in the image for that: it edits
the line and hands the finished answer to the tool. It steps aside where there
is nothing to edit — a pipe, the CI — and `copier` is left bare: wrapping it
would add a layer to a prompt that already edits.

### Where they come from

One family: `cruft` runs the cookiecutter engine and records what it generated
in `.cruft.json`, which is what makes `cruft update` possible; `ccds` is
cookiecutter plus the DrivenData template; `copier` is a separate
implementation of the same idea. `cookiecutter` itself is taken the same way
when a template's README says to run it:
`uvx --from cookiecutter cookiecutter …`.

### Adding a line

`fnew` ignores any line that is not four tab-separated columns, and says so on
stderr, naming the catalog it found the row in — a row typed with spaces would
otherwise simply never appear in the picker, which looks exactly like an empty
catalog. The safe way to append one is a `printf` with an explicit `\t`, which
cannot turn into spaces:

```bash
printf '%s\t%s\t%s\t%s\n' \
  'gh:owner/repo' 'copier' '' 'What it is (and the fact that justifies it)' \
  >> ~/.config/packs/python/cheatsheets/templates.tsv
```

That writes to the copy inside the instance, which `add_pack` put there by
copying the pack's folder. A rebuild throws the instance away, so an entry
meant to survive one belongs in the repository, in that pack's own
`cheatsheets/` — beside the file it feeds.

## Skipping the picker

```bash
gmake copier_project PROJECT_NAME=my-analysis PROJECT_TEMPLATE_REPO=gh:owner/python-copier-template-ds
gmake cruft_project PROJECT_TEMPLATE_REPO=gh:owner/cookiecutter-data-science PROJECT_TEMPLATE_VERSION=v1
```

Cruft and ccds are given no folder name: they ask for it themselves, and the
project lands in the directory their answer names.

Called by name, a target has no row to read, so it takes the pack whose step
runs from `TEMPLATE_PACK` in `.env.global` — which the packs' samples set to
`python`. `TEMPLATE_PACK=` on the command line copies the template, writes the
`.env`, and runs nothing else.
