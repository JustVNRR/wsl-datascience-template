# WSL Configuration

[← Back to the README](../../README.md#makefile-gmake)

The instance's own settings outside `~/.config`: the two files WSL reads, and
the command that reports what the instance runs on.

## Targets

| Target | Action | Confirmation |
| :--- | :--- | :--- |
| `wsl_config` | Open `/etc/wsl.conf` in nano, under sudo | — |
| `dns_resolve` | Open `/etc/resolv.conf` in nano, under sudo | — |
| `wsl_status` | Report what the instance runs on | — |

## The WSL file

`first_boot.sh` writes `/etc/wsl.conf` whole at the first boot; the values in it
are the ones chosen there. It holds three sections:

| Section | Sets |
| :--- | :--- |
| `[boot]` | what WSL starts with the instance — a `command=` run as root, and `systemd=true` once systemd is installed ([systemd](systemd.md)) |
| `[user]` | `default=` — the account a new session opens as |
| `[interop]` | `enabled`, `appendWindowsPath` — whether Windows programs, and the Windows `PATH`, are visible from here |

## The resolver file

`/etc/resolv.conf` is where the instance reads its name servers. What it is at
the moment you look decides what an edit is worth, and that is what the command
reports before opening it:

| State | What it means |
| :--- | :--- |
| a symlink (to `/mnt/wsl/resolv.conf`) | WSL's own: written again at every start of the instance, so an edit goes with the next one. A change that must stay needs `generateResolvConf = false` in `/etc/wsl.conf` — and a file of your own in place of the symlink. |
| absent | nothing resolves until one exists. WSL writes its own again at the next start, unless the setting above is in place. |
| a real file | yours, or openresolv's — the web pack's tunnel writes it at each mount, while it is up. |

`/mnt/wsl` is a tmpfs shared by every distro of the WSL virtual machine, so
while the file is a symlink, an edit through it is a change the neighbours see
too.

## The status command

`wsl_status` changes nothing: it reads the instance and prints five blocks.

| Block | Shows |
| :--- | :--- |
| The distribution and the kernel | `uname -r`, and `PRETTY_NAME` from `/etc/os-release` |
| Init and systemd | what PID 1 is, and what `systemctl is-system-running` answers — not installed by default, then `offline` until the restart that boots it ([systemd](systemd.md)) |
| The local file | `/etc/wsl.conf`, or that it is absent |
| The Windows-wide file | `%USERPROFILE%\.wslconfig`, read through interop — the path it looked at is printed either way |
| Memory and services | `free -h`; systemd's services when it runs, the init.d ones otherwise |

## The editors

Both open their file in nano, under sudo: they belong to root, and an editor
without sudo would show them and then refuse to save them.

nano, and not `$EDITOR`: the instance's `$EDITOR` is `code --wait` whenever
VS Code is installed, and that `code` is the Windows one — it saves as the
Windows user, who cannot write a file that belongs to root.

Both files are read when the instance starts, so a change applies at the next
start — from Windows, `.\wsl.ps1 restart`.

## Variables

None of its own.
