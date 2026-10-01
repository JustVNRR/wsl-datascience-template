# The Instance's Own Settings

[← Back to the README](../../README.md#makefile-gmake)

What is the machine's and not a project's: the three files the instance keeps,
the ten switches that turn WSL's features on and off, and the command that
reports what the instance runs on.

## Targets

| Target | Action |
| :--- | :--- |
| `wsl_config` | Open `/etc/wsl.conf` in nano, under sudo |
| `dns_resolve` | Open `/etc/resolv.conf` in nano, under sudo |
| `fstab_config` | Open `/etc/fstab` in nano, under sudo |
| `wsl_status` | Report what the instance runs on |
| `systemd_up` | Install systemd and turn it on |
| `systemd_down` | Stop booting systemd (the packages stay installed) |
| `automount_up` | Mount the Windows drives under `/mnt` at every start |
| `automount_down` | Stop mounting the Windows drives |
| `interop_up` | Let the instance run Windows programs |
| `interop_down` | Stop running Windows programs from the instance |
| `windows_path_up` | Add the Windows `PATH` to this instance's `PATH` |
| `windows_path_down` | Keep the Windows `PATH` out of this instance's `PATH` |
| `fstab_up` | Apply `/etc/fstab` at every start |
| `fstab_down` | Leave `/etc/fstab` alone at start |

## The WSL file

`first_boot.sh` writes `/etc/wsl.conf` whole at the first boot; the switches
below add `[boot]` or edit the sections, and a pack may add its own.

| Section | Sets |
| :--- | :--- |
| `[boot]` | what WSL starts with the instance — a `command=` run as root, and `systemd=true` once `systemd_up` has run |
| `[user]` | `default=` — the account a new session opens as |
| `[automount]` | `enabled` — whether the Windows drives appear under `/mnt`; `mountFsTab` — whether `/etc/fstab` is applied at start (false until `fstab_up`) |
| `[interop]` | `enabled` — whether Windows programs can be run from here; `appendWindowsPath` — whether the Windows `PATH` is appended to this instance's `PATH` |

## The resolver file

`/etc/resolv.conf` is where the instance reads its name servers. What the file
is when you look decides what an edit is worth, and the command says so before
opening it:

| State | What it means |
| :--- | :--- |
| a symlink (to `/mnt/wsl/resolv.conf`) | WSL's own: written again at every start, so an edit goes with the next one. A change that must stay needs `generateResolvConf = false` in `/etc/wsl.conf` — and a file of your own in place of the symlink. |
| absent | nothing resolves until one exists. WSL writes its own again at the next start, unless the setting above is in place. |
| a real file | yours, or openresolv's — the web pack's tunnel writes it at each mount, while it is up. |

`/mnt/wsl` is a tmpfs shared by every distro of the WSL virtual machine, so
while the file is a symlink, an edit through it is a change the neighbours see
too.

## The fstab file

`/etc/fstab` is the list of what to mount at start, and where. The instances
carry it empty, and `mountFsTab = false` keeps it out of the way: `fstab_up`
is what applies it at start. `fstab_config` opens it, and `sudo mount -a`
applies an edit right away.

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

Each edits the line and nothing else: the other sections and the comments stay,
a missing section is created, and running the same one twice changes nothing.
The `windows_path` pair only matters while `interop` is on — and `interop_down`
also silences the Windows block of `wsl_status`.

The real state of three pairs — automount, interop, the Windows `PATH` — is
reported by `wsl_status` rather than by a target of its own, and read from the
machine: the mount table, a Windows program really run, the `PATH` itself.
Each comes back as a trailing comment on the pair's line of `/etc/wsl.conf` —
see [the status command](#the-status-command).

Turning the drives off does not cut an instance off from its packs:
`.\wsl.ps1 add_pack` travels through Windows' own share when nothing is mounted.

### What systemd brings

The image ships none: nothing it starts is a service, and the `systemd` package
alone never boots anything — WSL runs its distribution's `/sbin/init`, which
`systemd-sysv` poses. `systemd_up` installs it with `libpam-systemd` and
`dbus-user-session` (WSL's user session needs them), and writes the line;
`systemd_down` puts the line back to `false` and leaves the packages. It also
masks the two units WSL cannot use — `kmod-static-nodes` (WSL owns `/dev`),
`systemd-binfmt` (no `binfmt_misc` here) — and clears their failure, so
`systemctl is-system-running` says `running`, not `degraded`. `systemd is
already enabled` is said only when PID 1 really is systemd. Everything is
installed with `--no-install-recommends`, packages named: `systemd-resolved`
stays out — a rival of the resolver the [web
pack](../../packs/web/docs/vpn.md) installs.

When it is on: services started with the instance, restarted when they fall,
`journalctl`, timers.

## The status command

`wsl_status` changes nothing: it reads the instance and prints five blocks.

| Block | Shows |
| :--- | :--- |
| The distribution and the kernel | `uname -r`, and `PRETTY_NAME` from `/etc/os-release` |
| Init and systemd | what PID 1 is, and what `systemctl is-system-running` answers — not installed by default, then `offline` until the restart that boots it |
| The local file | `/etc/wsl.conf`, or that it is absent — three of its lines carry `# OK` / `# NOK` |
| The Windows-wide file | `%USERPROFILE%\.wslconfig`, read through interop — the path it looked at is printed either way |
| Memory and services | `free -h`; systemd's services when it runs, the init.d ones otherwise |

Three lines can carry that comment: `[automount] enabled`, `[interop] enabled`
and `[interop] appendWindowsPath`. `# OK` means the instance really is in the
state the line declares, `# NOK` that it is not — most often a switch just
thrown whose restart has not happened yet (`.\wsl.ps1 restart`, from Windows).
The other lines are printed as they are.

## The editors

`wsl_config`, `dns_resolve` and `fstab_config` open their file in nano, under
sudo — the files belong to root. nano, not `$EDITOR`: at these commands
`$EDITOR` is `code --wait`, the Windows one, which saves as the Windows user
and cannot write root's files. An edit takes effect at the next start:
`.\wsl.ps1 restart`, from Windows.

## Variables

None of its own.
