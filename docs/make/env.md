# Environment Files

[← Back to the README](../../README.md#mlops-makefile-gmake)

The two files every gmake target reads, and the commands that build them from
the samples — and open them in the editor.

## Targets

| Target | Action | Confirmation |
| :--- | :--- | :--- |
| `env_global_enable` | Create or complete `~/.config/zsh/gmake/.env.global` | — |
| `env_global_manage` | The same, then open the file in the editor | — |
| `env_project_enable` | Create or complete the current project's `.env` | — |
| `env_project_manage` | The same, then open the file in the editor | — |

## The cascade

| File | Holds | Read by |
| :--- | :--- | :--- |
| `~/.config/zsh/gmake/.env.global` | the values shared by every project | make, for every project |
| `<project>/.env` | what identifies this project | make, and the Python code (`load_dotenv`) |

make loads the first, then the second: a variable set in the project's `.env`
wins. A sample is never read — it is a template, and the filled copy is what
gets loaded.

## The samples

Both files are assembled from samples, and the socle owns the two that open
them: `zsh/gmake/env.global.sample` and `zsh/gmake/env.project.sample`. Each pack
ships its block beside the modules that read it — `packs/gcp/env.project.sample`
for the Google Cloud variables, `packs/devops/env.project.sample` for the docker
ones. A pack with nothing of its own to declare ships no sample.

The socle's two come first, and they carry the header: the rule, and what
belongs in the file. Then every installed pack's, in the order their folders
sort.

## What the two `_enable` commands do

Each reads the socle's sample and those of every pack installed, and writes the
real file. **It only ever appends**: a variable the file already defines is left
alone. So

- running it twice changes nothing the second time;
- a value you filled in is never overwritten, not even by an updated sample;
- a pack's variables arrive the next time you run it after adding that pack.

On a file that does not exist yet, the samples are copied whole — comments
included — so the file arrives already documented. The socle's sample comes
first, and it carries the header: the rule, and what belongs in the file.

On a file that is already there, only the variables travel. The sample's
comments stay with the sample, and what comes in lands under a single header
line saying where it came from — a pack's block is documented one folder away,
in the sample it ships, and never re-explained in your own file.

With no readable sample at all, the command says so and writes nothing: an
empty `.env` would look like an answer.

## The editor

The two `_manage` targets are their `_enable` twins with the editor on the end:
create or complete the file, then open it in `$EDITOR` — nano when the shell
exports none. The merge runs first on purpose: a file that is not there yet is
created whole from the samples, header included, so the editor never opens on
an empty one.

## Variables

The commands have none of their own. A pack's variables are documented with the
module that reads them — the devops pack's three, on its
[Docker page](../../packs/devops/docs/docker.md).

One of them, `DOCKER_LOCAL_IMAGE`, is refused in `.env.global`: it names a
project. Each pack lists the variables that identify one in its `pack.conf`, and
the socle's gate refuses those at load time, with an explicit error, from
wherever the file is read.

## Where the commands live

In `zsh/gmake/make/env.mk`, beside the Makefile that reads `.env.global` — the
same argument as the two macros: a file the socle loads cannot be a pack's to
build. The `env_global_*` targets write, then open, a machine-wide file and run
from anywhere; the `env_project_*` ones run from the root of a project, like
every other target that reads one.
