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

Removing the pack takes the program, the versions it keeps, and the provider keys
it wrote in the settings. `~/.claude` — settings, credentials, history, sessions —
and your dictionary stay where they are: they are yours, like `~/.mozilla` when
the `web` pack goes. A filled `.env.global` keeps its line too.

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
| a key | an API key — from the Console, a gateway, or a provider that speaks the same API | keep it in the dictionary, and apply it — [which provider](#which-provider) |
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

## Which provider

A key needs somewhere to live, and several providers is several keys. The pack
keeps them in one file of yours:

| | |
| :--- | :--- |
| `~/.config/claude/profiles.json` | one entry per provider — an id, a base URL, a token, and a model if you want one |
| `gmake claude_edit_profiles` | opens it in the editor (nano, or `$EDITOR`) |
| `gmake claude_profile` | picks one from a menu, and applies it |
| `gmake claude_profile CLAUDE_PROFILE=glm` | applies that one, without the menu |
| `CLAUDE_PROFILE` in `.env.global` | the entry in use |

An entry with no `env` at all is this instance's own login — the subscription
route. Choosing it takes back whatever another entry had written.

**Where it lands**: the `env` block of `~/.claude/settings.json`, the file the
CLI reads for itself — so the choice holds for a `claude` typed by hand, for a
`-p` run in a pipe, and for whatever the CLI starts on its own. The pack writes
the `ANTHROPIC_*` keys and the ones your entries declare, and nothing else: your
`statusLine`, your permissions and your own variables are not touched.
Removing the pack takes those keys back out.

**A base URL always comes with a token.** The CLI sends whatever credential it
has to the address you name, and the one it always has is your claude.ai login —
the header leaves with the OAuth in it. A profile carrying a URL and no token is
refused rather than applied.

`gmake claude_status` says which entry is in force and whether what the settings
hold is what that entry says — which is how a token rotated in the file and not
applied gets noticed.

Third-party endpoints are named nowhere in Anthropic's documentation: what is
documented is the *gateway* mechanism — "a proxy your organization runs" — and
GLM, DeepSeek or Kimi are that mechanism pointed elsewhere. Some of what Claude
Code does depends on Anthropic's own API and stops behind a gateway: the tool
search, Remote Control, the dictation, and prompt caching unless the endpoint
forwards `cache_control`.

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
