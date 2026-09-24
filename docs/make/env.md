# Environment Files

[← Back to the README](../../README.md#mlops-makefile-gmake)

The two files every gmake target reads, and the commands that build them from
the samples.

## Targets

| Target | Action | Confirmation |
|---|---|---|
| `env_global_enable` | Create or complete `~/.config/zsh/gmake/.env.global` | — |
| `env_project_enable` | Create or complete the current project's `.env` | — |

## The cascade

| File | Holds | Read by |
|---|---|---|
| `~/.config/zsh/gmake/.env.global` | the values shared by every project | make, for every project |
| `<project>/.env` | what identifies this project | make, and the Python code (`load_dotenv`) |

make loads the first, then the second: a variable set in the project's `.env`
wins. A sample is never read — it is a template, and the filled copy is what
gets loaded.

## What the two commands do

Each reads the socle's sample and those of every pack present, and writes the
real file. **It only ever appends**: a variable the file already defines is
left alone. So

- running it twice changes nothing the second time;
- a value you filled in is never overwritten, not even by an updated sample;
- a pack's variables arrive the next time you run it after adding that pack.

On a file that does not exist yet, the samples are copied whole — comments
included — so the file arrives already documented.

## Variables

None of its own. This module reads the samples the modules and packs ship
beside themselves; the variables and their meanings belong to those pages.
