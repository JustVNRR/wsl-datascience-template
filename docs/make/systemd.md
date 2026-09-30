# systemd

[← Back to the README](../../README.md#makefile-gmake)

The service manager, off by default and installed on demand.

## Targets

| Target | Action | Confirmation |
| :--- | :--- | :--- |
| `systemd_enable` | Install systemd and turn it on for this instance | — |
| `systemd_disable` | Stop booting systemd (the packages stay installed) | — |

## Why it is not there by default

Nothing the image starts is a service. The projects bring their own tools,
Docker comes from Docker Desktop, and a pack that needs something at boot uses
WSL's own `[boot] command=` hook — the web pack does. systemd would cost about
19 MB and take over PID 1 with all its units, which is worth paying only when
something needs it.

## What it brings

The standard way to run a service: it starts with the instance, restarts when
it falls, logs to `journalctl`, schedules timers. On a server that is the rule;
here it is an option.

## What the commands do

`systemd_enable` installs `systemd-sysv` — which brings systemd and the
`/sbin/init` file WSL runs; the `systemd` package alone, the one the image used
to carry, boots nothing — and writes `systemd=true` into `/etc/wsl.conf`. One
sudo, and the file is only written if the installation worked: a half-enabled
instance is not a state to leave behind.

It installs with `--no-install-recommends`, like every apt line of the image:
what systemd merely recommends includes `systemd-resolved`, a rival of the
resolver the [web pack](../../packs/web/docs/vpn.md) installs.

`systemd_disable` puts the line back to `false` and touches nothing else. The
packages stay installed; they do nothing while systemd is off.

Both edit the file and nothing else in it: the other sections and the comments
stay as they are, and the `[boot]` block is created only when the file has
none. Running either one twice changes nothing the second time.

Neither takes effect immediately: WSL reads the file when the instance starts,
and systemd becomes PID 1 at that moment. Restart with `.\wsl.ps1 restart`,
then `gmake wsl_status` says what it runs on.

## Variables

None of its own.
