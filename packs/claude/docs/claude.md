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

If Claude Code is already installed on Windows, the instance sees it — WSL puts
the Windows folders on the PATH — and the install asks before adding a second
copy here. A bare Enter declines, and the pack is not installed.

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

## Getting in

Claude Code needs one thing to talk to a model: a credential. There are two
kinds, and a key needs no login at all.

| Route | What it is | What you do |
| :--- | :--- | :--- |
| a key | an API key — from the Console, a gateway, or a provider that speaks the same API | put it in the `env` block of `~/.claude/settings.json` as `ANTHROPIC_AUTH_TOKEN` |
| a login | a Pro, Max, Team, Enterprise or Console subscription — there is no key to copy | let `claude` open the authorisation page once |

`ANTHROPIC_AUTH_TOKEN` is used as it stands, with nothing to approve.
(`ANTHROPIC_API_KEY` works too, but the first interactive session asks you to
approve it once.) Either one outranks a stored login, so a key is the whole
configuration.

The login is a web page: the CLI opens a browser and waits for the page to hand
the code back. An instance carries no browser, so the CLI prints the URL — open
it in your own browser on Windows, and paste back the code the page shows you.
If the paste does not take, `claude auth login` reads the code from your input
instead.

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

## The one on Windows is not this one

WSL puts the Windows folders on the instance's PATH, so a Claude Code installed
on Windows answers from inside the instance: `claude` works, and it is running on
the other side of the wall — Windows paths, Windows files, and not the program
this pack installed. `gmake claude_status` reads the pack's own launcher, at
`~/.local/bin/claude`, and names the foreign one when it is all there is.
