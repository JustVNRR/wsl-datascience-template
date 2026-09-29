# Claude Code

[← Back to the README](../../../README.md#optional-tooling)

Anthropic's agentic CLI, inside the instance. It is a terminal program — no
window, nothing on the Windows desktop — and it installs itself under your own
`~/.local`: no apt package, no root, and no Node, which the image does not carry.

| Piece | For | Commands |
| :--- | :--- | :--- |
| the program | a session, in a project or anywhere | `claude` |
| what this instance has | version, versions kept, the login | `gmake claude_status` |

## Installing and removing it

```powershell
.\wsl.ps1 add_pack      # pick the instance, then claude
.\wsl.ps1 remove_pack   # the reverse
```

Removing the pack takes the program and the versions it keeps. `~/.claude` —
settings, credentials, history, sessions — stays where it is: it is yours, like
`~/.mozilla` when the `web` pack goes.

## What it costs

| | |
| :--- | :--- |
| the download | about 230 MB, a few minutes on a slow link |
| one version on disk | **232 MiB** (measured: one 243 MB binary) |
| the versions kept | the CLI keeps every version it installs, so each update adds about as much again |

`gmake claude_status` shows what is on the disk; the last lines of the
[cheatsheet](../cheatsheets/claude_commands.sh) show how to reclaim it.

## The first run

`claude` asks you to log in once, and **needs a paid plan** — Pro, Max, Team,
Enterprise or Console. The free claude.ai plan does not include Claude Code.

The login is a web page, so the CLI opens a browser and waits for it to come
back. An instance carries no browser: open the URL the CLI prints on Windows,
and paste back the code the page gives you — the browser on Windows cannot call
into the instance on its own. If the paste does not take, `claude auth login`
reads the code from your input instead.

## Where things live

| Path | What it is |
| :--- | :--- |
| `~/.local/bin/claude` | the launcher — a symlink into the versions below |
| `~/.local/share/claude/versions/` | every version installed, one file each |
| `~/.claude/` | settings, credentials, prompt history, sessions |
| `~/.claude/settings.json` | the settings the CLI reads at every start |

`~/.local/bin` is already on the PATH — the socle exports it — so the note the
installer prints, asking you to add it to your shell's configuration file, needs
nothing done about it.
