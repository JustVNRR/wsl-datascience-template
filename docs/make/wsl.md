# WSL Configuration

[← Back to the README](../../README.md#makefile-gmake)

The file WSL reads when this instance starts — which account it opens as, what
WSL runs at that moment, how the Windows side is reached.

## Target

| Target | Action | Confirmation |
| :--- | :--- | :--- |
| `wsl_config` | Open `/etc/wsl.conf` in nano, under sudo | — |

## The file

`first_boot.sh` writes `/etc/wsl.conf` whole at the first boot; the values in it
are the ones chosen there. It holds three sections:

| Section | Sets |
| :--- | :--- |
| `[boot]` | what WSL starts with the instance — `systemd=true`, and a `command=` run as root |
| `[user]` | `default=` — the account a new session opens as |
| `[interop]` | `enabled`, `appendWindowsPath` — whether Windows programs, and the Windows `PATH`, are visible from here |

## What the command does

It opens the file in nano, under sudo: the file belongs to root, and an editor
without sudo would show it and then refuse to save it.

nano, and not `$EDITOR`: the instance's `$EDITOR` is `code --wait` whenever
VS Code is installed, and that `code` is the Windows one — it saves as the
Windows user, who cannot write a file that belongs to root.

WSL reads the file when the instance starts, so a change applies at the next
start: from Windows, `.\wsl.ps1 stop`, then `.\wsl.ps1 start`.

## Variables

None of its own.
