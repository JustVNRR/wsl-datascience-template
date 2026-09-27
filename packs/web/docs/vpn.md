# The tunnel (WireGuard)

[← Back to the README](../../../README.md#optional-tooling) · [The pack](web.md)

A WireGuard tunnel inside the instance, driven by `gmake`, from the profile
Proton gives your account. No Proton application is involved: the profile *is*
the authentication.

**What a tunnel here covers, and what it does not.** It carries the traffic of
this distro — Firefox, `curl`, `pip`, a `git push`. It does not cover Windows,
your other distros, or Docker Desktop: Windows keeps its own network. If the
whole machine should be covered, that is a different arrangement (WSL's
`networkingMode=mirrored` with the Windows application), not this pack.

## The targets

| Target | What it does |
| :--- | :--- |
| `vpn_status` | Up or down, which profile, where the DNS goes, the exit IP, and what the distro starts with |
| `vpn_up [profile]` | Connect now. Without a name, the menu lists the profiles; if another one is up, it goes down first |
| `vpn_down` | Disconnect |
| `vpn_server [profile]` | The server the distro starts with — and switches to it now if a tunnel is up |
| `vpn_auto_on [profile]` | Bring the tunnel up when the distro starts |
| `vpn_auto_off` | Stop doing that |

The profile can be named on the command line to skip the menu:
`gmake vpn_up VPN_PROFILE=ch`.

## The profiles

One file per server in `/etc/wireguard`, mode `600`, root — `proton.conf`,
`ch.conf`, `nl.conf`. They hold your private key and they are yours: the pack
writes in none of them, and removing the pack does not delete them.

```powershell
.\wsl.ps1 add_pack      # pick the instance, then web
```

The pack leaves one profile behind when the folder holds none: the sample from
its own folder, with everything but the keys — so there is only one file to
paste into instead of one to write.

```bash
sudo nano /etc/wireguard/proton.conf    # paste the two keys, keep the rest
sudo chmod 600 /etc/wireguard/proton.conf
```

A key that leaks is revoked **in your Proton account** (WireGuard → delete the
configuration): the server then refuses every new handshake. The profile on the
machine stops working, and nothing else needs undoing.

## The DNS

`openresolv` owns `/etc/resolv.conf`, and the profile's `DNS = 10.2.0.1` is
applied when the tunnel comes up and released when it goes down — so
`gmake vpn_status` says where the names are resolved, tunnel up or down.

Two things this needs, both done by the install: `generateResolvConf = false` in
`/etc/wsl.conf` (otherwise WSL rewrites the file at every start), and
`openresolv` itself, which is not in Ubuntu 24.04's archive — the pack takes it
from Debian's package, and removes `systemd-resolved` first, because the two
claim the same `resolvconf` command.

## The kill switch

It is in the profile, not in the pack — two `iptables` lines, `PostUp` and
`PreDown`, that reject anything not travelling through the tunnel. The
consequence, worth knowing before turning it on: while a tunnel is up, services
running **on Windows** and reached through the WSL gateway are rejected too.
Local destinations (loopback, WSLg, the Docker socket) are spared.

## Starting with the distro

`vpn_auto_on` writes two things: the profile's name in `/etc/wireguard/auto`,
and one line in `/etc/wsl.conf`:

```ini
[boot]
command=/usr/local/sbin/web-vpn-boot
```

That is WSL's own boot hook, not a systemd unit — see
[why below](#why-not-a-systemd-unit). It runs as root, retries while the network
comes up, always exits, and writes what it did to `/var/log/web-vpn.log` —
`vpn_status` shows the last line of it.

**The tunnel lives as long as the distro does.** WSL stops a distro shortly
after its last session closes, so "starts with the distro" means "starts when
something starts the distro": a terminal, VS Code, Docker Desktop. A tunnel kept
up while nothing is running would need something on the Windows side to start
the distro — a scheduled task — and that is a decision about the machine, not
about this pack.

## Why not a systemd unit

`/etc/wsl.conf` declares `systemd=true`, but WSL boots systemd by running
`/sbin/init`, which the `systemd` package alone does not provide (that is
`systemd-sysv`, and an instance built from this image does not carry it). So
`systemctl` answers `System has not been booted with systemd` here, and the
`[boot] command=` hook is the mechanism that works — no unit, no timer, no
journal. Adding `systemd-sysv` to the image would boot systemd *and* its units,
including `systemd-resolved` — the very package the pack removes so that
`openresolv` can own the resolver, which is why this pack leaves the image alone.

## Removing the pack

`.\wsl.ps1 remove_pack` takes the tunnel down, removes the boot hook and the
boot script, removes the packages (a package another installed pack still claims
stays), and takes `openresolv` back out — with the line to restore
`systemd-resolved` if you want it back.

What it leaves alone, on purpose: your profiles in `/etc/wireguard` (your keys),
`generateResolvConf = false` in `/etc/wsl.conf` (a machine setting, not the
pack's), and Firefox's profile in `~/.mozilla`.
