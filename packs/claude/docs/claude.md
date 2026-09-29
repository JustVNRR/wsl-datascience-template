# Claude Code

[← Back to the README](../../../README.md#optional-tooling)

Anthropic's agentic CLI, inside the instance. It is a terminal program — no
window, nothing on the Windows desktop — and it installs itself under your own
`~/.local`: no apt package, no root, and no Node, which the image does not carry.

| Piece | For | Commands |
| :--- | :--- | :--- |
| the program | a session, in a project or anywhere | `claude` |
| your projects | pick up work where it stopped | `gmake claude_project` |
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
| `~/.config/claude/profiles.json` | one entry per provider — an id, then the environment that provider needs |
| `gmake claude_edit_profiles` | opens it in the editor (nano, or `$EDITOR`) |
| `gmake claude_profile` | picks one from a menu, and applies it |
| `gmake claude_profile CLAUDE_PROFILE=glm` | applies that one, without the menu |
| `CLAUDE_PROFILE` in `.env.global` | the entry in use |

An entry is the environment Claude Code reads — the same names as in
`settings.json`, so a block you already have goes in as it stands:

```json
{ "id": "deepseek",
  "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
  "ANTHROPIC_AUTH_TOKEN": "…",
  "ANTHROPIC_MODEL": "deepseek-chat" }
```

`id` and `note` belong to the file; every other key is the provider's. An entry
with only an `id` is this instance's own login — the subscription route — and
choosing it takes back what another entry had written.

**Where it lands**: the `env` block of `~/.claude/settings.json`, the file the
CLI reads for itself — so the choice holds however you start Claude Code: from
the prompt, in a pipe, or from what the CLI starts itself.

**What the pack owns there**: every key any of your entries names, plus
`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY` and
`ANTHROPIC_MODEL`. Loading an entry writes its keys; switching to one that does
not carry a key takes it out. Everything else is untouched — your `statusLine`,
your permissions, and any variable no entry names. Removing the pack takes those
keys back out.

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

## Your projects

Claude Code keeps one history per folder it has run in. `gmake claude_project`
turns that into a menu: this instance's projects, the most recently used first,
each with the date of its last session.

```text
  2026-09-28 18:04  ~/projects/demo
  2026-09-12 09:21  ~/projects/pricing
```

Pick one and a session opens in that folder, continuing the conversation that
was left there — nothing to `cd` into, nothing to remember.

A folder that has been deleted is not offered, and a folder no session has run
in is not in the list either: there would be nothing to continue. On an instance
that has never run a session, the target says so and stops.

From inside a folder, the same thing is the CLI's own `claude --continue`.

## The status line

Installing the pack gives the instance a status line for its sessions, on two
rows:

```text
 Opus 5.5 |  max |  ctx 86k/200k (43%)
 glm |  py: .venv |  main |  #12 pending |  ~/projects/demo
```

Row 1 is what is running: the model, the effort, how full the context is. Row 2
is where: which provider the pack has in force, the python environment, the
branch, the pull request when the branch has one, and the folder last — the one
value whose length nobody controls, so being cut is the right job for it.

The script is the pack's, `bin/statusline.sh`, declared in
`~/.claude/settings.json` as the `statusLine` — **only when you have none**: a
status line of your own is yours, and the pack leaves it alone. Removing the pack
takes back the one it wrote, and only while it is still that one.

The icons are Nerd Font glyphs, which the font this template asks for carries; a
font that does not shows a box, and each icon is one line at the top of the
script.

## Where things live

| Path | What it is |
| :--- | :--- |
| `~/.local/bin/claude` | the launcher — a symlink into the versions below |
| `~/.local/share/claude/versions/` | every version installed, one file each |
| `~/.claude/` | settings, credentials, prompt history, sessions |
| `~/.claude/projects/` | one folder per project this instance has worked in — what `claude_project` lists |
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
