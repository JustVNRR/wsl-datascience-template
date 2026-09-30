# The Instance's Own Settings

[← Back to the README](../../README.md#makefile-gmake)

What is the machine's and not a project's: the three files the instance keeps,
the ten switches that turn WSL's features on and off, and the command that
reports what the instance runs on.

## Targets

| Target | Action | Confirmation |
| :--- | :--- | :--- |
| `wsl_config` | Open `/etc/wsl.conf` in nano, under sudo | — |
| `dns_resolve` | Open `/etc/resolv.conf` in nano, under sudo | — |
| `fstab_config` | Open `/etc/fstab` in nano, under sudo | — |
| `wsl_status` | Report what the instance runs on | — |
| `systemd_up` | Install systemd and turn it on | — |
| `systemd_down` | Stop booting systemd (the packages stay installed) | — |
| `automount_up` | Mount the Windows drives under `/mnt` at every start | — |
| `automount_down` | Stop mounting the Windows drives | — |
| `interop_up` | Let the instance run Windows programs | — |
| `interop_down` | Stop running Windows programs from the instance | — |
| `windows_path_up` | Add the Windows `PATH` to this instance's `PATH` | — |
| `windows_path_down` | Keep the Windows `PATH` out of this instance's `PATH` | — |

## The WSL file

`first_boot.sh` writes `/etc/wsl.conf` whole at the first boot; the values in it
are the ones chosen there. It holds these sections — the switches below add
`[boot]` or edit the others, and a pack may add its own:

| Section | Sets |
| :--- | :--- |
| `[boot]` | what WSL starts with the instance — a `command=` run as root, and `systemd=true` once `systemd_up` has run |
| `[user]` | `default=` — the account a new session opens as |
| `[automount]` | `enabled` — whether the Windows drives appear under `/mnt`; `mountFsTab` — whether `/etc/fstab` is applied at start (false by default, `fstab_up` turns it on) |
| `[interop]` | `enabled` — whether Windows programs can be run from here; `appendWindowsPath` — whether the Windows `PATH` is appended to this instance's `PATH` |

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

## The fstab file

`/etc/fstab` is the list of what to mount at start, and where — a disk image, a
network share, anything its format can name. The instances carry it empty, and
`mountFsTab = false` in `/etc/wsl.conf` keeps it out of the way: `fstab_up` is
what applies it at start. `fstab_config` opens it, and `sudo mount -a` applies
an edit right away, without waiting for a restart.

## The ten switches

`_up` turns a feature on, `_down` turns it off, and both take effect at the next
start.

| Pair | Writes | Feature |
| :--- | :--- | :--- |
| `systemd_up` / `systemd_down` | `[boot] systemd=` | systemd becomes PID 1, or stops being it |
| `automount_up` / `automount_down` | `[automount] enabled=` | the Windows drives under `/mnt` |
| `interop_up` / `interop_down` | `[interop] enabled=` | Windows programs runnable from the instance (`code`, `powershell.exe`) |
| `windows_path_up` / `windows_path_down` | `[interop] appendWindowsPath=` | the Windows `PATH` appended to this instance's `PATH` |
| `fstab_up` / `fstab_down` | `[automount] mountFsTab=` | whether `/etc/fstab` is applied at start |

Each edits the line and nothing else in the file: the other sections and the
comments stay, the section is created only when the file has none, and running
the same one twice changes nothing. `interop_down` also silences the Windows
block of `wsl_status` — with interop off, Windows is not reachable. The
`windows_path` pair only matters while `interop` is on.

### What systemd brings

The image ships none, and that is deliberate: nothing it starts is a service,
and the `systemd` package alone never boots anything — WSL runs the
distribution's `/sbin/init`, which comes from `systemd-sysv`. `systemd_up`
installs three packages — `systemd-sysv`; `libpam-systemd` and
`dbus-user-session`, which are what WSL's user session needs — about 22 MB
together, and writes the line; `systemd_down` puts the line back to `false` and
leaves the packages. When the three are already installed, nothing is
downloaded and nothing is asked.

It installs with `--no-install-recommends`, like every apt line of the image,
and names what it needs: that is also what keeps `systemd-resolved` out — a
rival of the resolver the [web pack](../../packs/web/docs/vpn.md) installs, and
only ever a recommendation.

What it brings when it is on: the standard way to run a service — it starts with
the instance, restarts when it falls, logs to `journalctl`, schedules timers. On
a server that is the rule; here it is an option.

## The status command

`wsl_status` changes nothing: it reads the instance and prints five blocks.

| Block | Shows |
| :--- | :--- |
| The distribution and the kernel | `uname -r`, and `PRETTY_NAME` from `/etc/os-release` |
| Init and systemd | what PID 1 is, and what `systemctl is-system-running` answers — not installed by default, then `offline` until the restart that boots it |
| The local file | `/etc/wsl.conf`, or that it is absent |
| The Windows-wide file | `%USERPROFILE%\.wslconfig`, read through interop — the path it looked at is printed either way |
| Memory and services | `free -h`; systemd's services when it runs, the init.d ones otherwise |

## The editors

`wsl_config`, `dns_resolve` and `fstab_config` open their file in nano, under
sudo: they belong to root, and an editor without sudo would show them and then
refuse to save them.

nano, and not `$EDITOR`: the instance's `$EDITOR` is `code --wait` whenever
VS Code is installed, and that `code` is the Windows one — it saves as the
Windows user, who cannot write a file that belongs to root.

Both files are read when the instance starts, so a change applies at the next
start — from Windows, `.\wsl.ps1 restart`.

## Variables

None of its own.
