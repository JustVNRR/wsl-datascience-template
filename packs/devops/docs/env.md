# Environment Files

[← Back to the README](../../../README.md#mlops-makefile-gmake)

The two files every gmake target reads, and the commands that build them from
the samples.

## Targets

| Target | Action | Confirmation |
| :--- | :--- | :--- |
| `env_global_enable` | Create or complete `~/.config/zsh/gmake/.env.global` | — |
| `env_project_enable` | Create or complete the current project's `.env` | — |

## The cascade

| File | Holds | Read by |
| :--- | :--- | :--- |
| `~/.config/zsh/gmake/.env.global` | the values shared by every project | make, for every project |
| `<project>/.env` | what identifies this project | make, and the Python code (`load_dotenv`) |

make loads the first, then the second: a variable set in the project's `.env`
wins. A sample is never read — it is a template, and the filled copy is what
gets loaded.

## What the two commands do

Each reads this pack's sample and those of every other pack installed, and
writes the real file. **It only ever appends**: a variable the file already
defines is left alone. So

- running it twice changes nothing the second time;
- a value you filled in is never overwritten, not even by an updated sample;
- a pack's variables arrive the next time you run it after adding that pack.

On a file that does not exist yet, the samples are copied whole — comments
included — so the file arrives already documented. This pack's sample comes
first, and it carries the header: the rule, and what belongs in the file.

On a file that is already there, only the variables travel. The sample's
comments stay with the sample, and what comes in lands under a single header
line saying where it came from — a pack's block is documented one folder away,
in the sample it ships, and never re-explained in your own file.

With no readable sample at all, the command says so and writes nothing: an
empty `.env` would look like an answer.

## Variables

None of its own in `.env.global` — the three it reads identify one project and
live in `.env`:

| Variable | Read by |
| :--- | :--- |
| `PACKAGE_NAME` | `docker_build_local` |
| `DOCKER_BASE_IMAGE` | `docker_build_local` |
| `DOCKER_LOCAL_IMAGE` | `docker_build_local`, `docker_run_local` |

`DOCKER_LOCAL_IMAGE` is refused in `.env.global` at load time: it names a
project, and the socle's gate reads that list from this pack's `pack.conf`.
