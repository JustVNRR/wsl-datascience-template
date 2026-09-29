# What a Target Says Before It Runs

[← Back to the README](../../README.md#makefile-gmake)

Two macros of the socle, used by every module that writes a target — the
socle's own and the packs' alike. They are how a target is written, the way
the location gate in the Makefile says where it may run: a pack that writes a
target uses them and declares nothing.

| Macro | What it does | Called by |
| :--- | :--- | :--- |
| `check_vars VARS` | Refuses to run when one of `VARS` is unset. Warns when the values in effect come from neither a project `.env` nor the command line. | `docker_*`, and every GCP target |
| `confirm_action TITLE VARS` | Prints `TITLE` and the value of each variable, then waits for a `y`. | every target that creates or deletes something |

Both are `define`d, never run: they cost nothing until a recipe calls them, so
the module can be loaded before or after the targets that use it.

The third macro, `merge_env_samples`, sits in `make/env.mk` beside the targets
that call it and is the socle's for the same reason: it assembles the `.env`
files, and the `.env.global` it builds is loaded by this Makefile before it
reads a single pack. See [Environment files](env.md).

## The one thing to know

**A pack must never define any of the three.** The socle's modules are read
first and the packs' after, so a pack's own `define check_vars` would win in
silence — and every target that calls it, the pack's neighbours included, would
lose its check. The CI greps for it on every push; a comment cannot notice.

The same shape of mistake is what these macros exist to prevent: an undefined
macro expands to nothing, so a target that calls `check_vars` does not fail, it
drops the check and runs.
