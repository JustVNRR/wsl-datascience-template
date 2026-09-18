# Optional Tooling

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

Install and remove, on demand, the CLIs the image does not ship — a lean base
should not mean a dead end, and an option you cannot undo is not an option.

## Targets

| Target | Lives in | In the menu when | Action |
|---|---|---|---|
| `gcp_install` | `make/install.mk` | `gcloud` is absent | Install the Google Cloud CLI (~409 MB), then rerun `gmake` |
| `gcp_uninstall` | `make/gcp.mk` | `gcloud` is installed | Remove the package (~409 MB freed); the APT repository and your logins stay |

Exactly one of the two is visible at any time. The menu lists what can be done
**now**, not what could be done: an install line next to an already installed
tool is noise, and the way out has to exist for the tool to be an option at all.

## How a module appears and disappears

`gmake help` is not written by hand: it is built by reading the **text** of the
files make loaded. The modules that need the Google Cloud CLI (`gcp`,
`bigquery`, `cloud_run`, `gcloud_compute`) are therefore loaded only when that
CLI is on the PATH — and unloaded, they contribute no line at all.

That is the whole point: on a fresh distro those four modules leave the menu
instead of advertising commands that would fail with `command not found`.
`gcp_install` is there instead, because `install.mk` is loaded in that same
state — the capability is hidden until it is installed, never hidden until you
know it exists.

This is also why the two faces are two files. A conditional inside one file
would not hide anything: the menu reads text, so an `ifeq` around a target
leaves that target's description in the file, and both faces would show up at
once.

Nothing is recorded anywhere. `gmake` asks the system again on every run, so
any install route works — `gcp_install`, a manual `apt-get install`, a
tarball. The menu follows at the next `gmake`, in both directions.

Only the modules whose CLI is missing from the image are gated: `gh` ships in
the image, and `docker` works through Docker Desktop's WSL integration.

What is detected is a **binary**, not an authentication: a `gcloud` that is
installed but not logged in still shows its targets, and they fail with
Google's own message ([onboarding](../gcp/onboarding.md) covers that step).

The APT repository itself — Google's signing key and its file in
`/etc/apt/sources.list.d` — stays in the image, a few kilobytes. Only the
package is left out, so there is no repository to configure at runtime, and
reinstalling later is the same one-liner.

The menu is sorted by target name: a command is where its name says it is,
whichever module defines it. The families stay together anyway, since they
share their prefix.

## After a rebuild

The CLI lives inside the distro: a rebuild takes it away with everything else
(see [Maintenance & Removal](../../README.md#maintenance--removal)). Rerun
`gcp_install` — a few minutes, and nothing else to redo. The same is true of a
distro you carry elsewhere as a VHDX.

## In CI

The static checks run on a machine that has none of these CLIs, and a target
can exist in only one install state. The menu is therefore captured twice and
concatenated before the cheatsheets are compared against it:

```bash
{ GCLOUD=x gmake help; GCLOUD= gmake help; }   # both states, in one file
```

A variable set on the command line wins over the makefile's `:=`, so `GCLOUD=x`
loads the gated modules anyway. The bare run is then asserted separately.
