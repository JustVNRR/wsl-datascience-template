# What a Target Says Before It Runs

[← Back to the README](../../../README.md#mlops-makefile-gmake)

Two macros, shared by every module that writes a target — in this pack and in
the others.

| Macro | What it does | Called by |
| :--- | :--- | :--- |
| `check_vars VARS` | Refuses to run when one of `VARS` is unset. Warns when the values in effect come from neither a project `.env` nor the command line. | `docker_*`, and every GCP target |
| `confirm_action TITLE VARS` | Prints `TITLE` and the value of each variable, then waits for a `y`. | every target that creates or deletes something |

Both are `define`d, never run: they cost nothing until a recipe calls them, so
the module can be loaded before or after the targets that use them.

## The one thing to know

An undefined macro expands to nothing. A target that calls `check_vars` on a
machine without this pack does not fail — it drops the check and runs. The same
goes for `confirm_action`, which is what stands between you and a deleted
dataset or VM.

That is why a pack whose targets call them needs this pack installed, and why
the two travel together.
