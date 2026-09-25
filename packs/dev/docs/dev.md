# The dev pack

[← Back to the README](../../../README.md#mlops-makefile-gmake)

The project targets: what a project is built, pushed and configured with. They
used to sit in the socle, where an instance that had no project yet was offered
a workspace with nothing to put in it.

This is the mirror of the [vision pack](../../vision/docs/vision.md): vision
brings a tool and no target, `dev` brings targets and no tool. Everything it
drives is already on the machine — `docker` comes from Docker Desktop, `gh`
from the image — so `install.sh` and `remove.sh` have nothing to do and say so.

## What it brings

| Module | Targets | Page |
| :--- | :--- | :--- |
| `env.mk` | `env_global_enable`, `env_project_enable` | [Environment files](env.md) |
| `docker.mk` | `docker_build_local`, `docker_run_local` | [Docker](docker.md) |
| `github.mk` | `gh_pr_create`, `gh_pr_toreview`, `gh_pr_wip`, `gh_pr_ls` | [GitHub PRs](github.md) |
| `macros.mk` | — (the two macros the targets above call) | [What a target says](macros.md) |

All of them run from the root of a project under `~/projects`, except
`env_global_enable`, which writes a machine-wide file.

## What it does not touch

`~/projects`. The pack wrote none of the projects in there, it does not delete
them when it leaves, and it does not create the folder either — it comes from
the image and outlives every pack.

## Without it

No `docker_build_local`, no `gh_pr_*`, no `env_*_enable`: an instance with no
project has nothing to build, push or configure. The two tools stay — `docker`
and `gh` are on the machine whatever the packs say, and their own commands are
in the cheatsheet picker (`docker_commands.sh`, `git_commands.sh`).
