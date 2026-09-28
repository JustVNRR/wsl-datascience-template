# The tunnel (WireGuard)

[← Back to the README](../../../README.md#optional-tooling) · [The pack](web.md)

A WireGuard tunnel inside the instance, driven by `gmake`, from the servers
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
| `vpn_status` | Up or down, the server, the kill switch, where the DNS goes, the exit IP, and what the distro starts with |
| `vpn_up [id]` | Connect now, with the server `VPN_PROFILE` names. Naming one — `gmake vpn_up VPN_PROFILE=ch` — uses it for this call only |
| `vpn_up_from_list` | Connect now, picking the server in a menu |
| `vpn_down` | Disconnect |
| `vpn_server [id]` | The server the distro starts with — and switch to it now if a tunnel is up |
| `vpn_ks_on` / `vpn_ks_off` | Put the kill switch in the tunnel, or take it out, and remount so it is true now |
| `vpn_auto_on` / `vpn_auto_off` | Bring the tunnel up when the distro starts, or stop doing that |
| `vpn_edit_profiles` | Open the JSON of servers in `$EDITOR` (nano when unset) |

The three that move the tunnel — `vpn_up`, `vpn_up_from_list`, `vpn_down` — end
by showing what `vpn_status` shows, and wait for the server's first handshake
before asking the exit IP, so the answer is about a tunnel that is really
connected. `wg-quick`'s own line-by-line trace is captured and printed **only
when it fails**, which is the moment it is worth reading.

## The servers

One file, yours: `~/.config/vpn/servers.json`, mode `600` (it carries your
private keys). An entry per server:

```json
{
  "id": "proton",
  "note": "the free server, NL",
  "address": "10.2.0.2/32, 2001:db8::2/128",
  "private_key": "…",
  "peer": {
    "public_key": "…",
    "endpoint": "198.51.100.1:51820",
    "allowed_ips": "0.0.0.0/0, ::/0"
  }
}
```

| Field | What it is |
| :--- | :--- |
| `id` | The name the menus show and that `VPN_PROFILE` carries: letters, digits, dot, dash, underscore |
| `note` | Yours, for you |
| `address` | What Proton gives the interface — keep the IPv4 and the IPv6 one, comma-separated |
| `private_key` | Your key |
| `peer.public_key`, `peer.endpoint`, `peer.allowed_ips` | The server's, from the same Proton file. The endpoint is an IPv4 address or an IPv6 one in brackets — `[2a00:7c80:0:3a1::10]:51820` — and both work, but only if this instance can reach them (see below) |
| `dns`, `mtu`, `peer.persistent_keepalive` | Optional, per entry. Without them the pack applies `10.2.0.1`, `1420`, and no keepalive — the same for every server |

The two keys and the address come from your Proton account: **Downloads**, then
**WireGuard configuration**. Adding a server is one more entry in that file —
there is no import command.

The pack seeds the file from its own sample when it is not there, and never
writes in it again: `vpn_edit_profiles` opens it, it does not rewrite it.
Removing the pack leaves it, and the profiles an older install kept in
`/etc/wireguard` — those are yours too.

## The two variables

| Variable | What it decides |
| :--- | :--- |
| `VPN_PROFILE` | The `id` of the server in use — and the one the distro starts with |
| `VPN_KILL_SWITCH` | `true`: the tunnel rejects what would leave outside it. `false`: it does not |

Both live in `~/.config/zsh/gmake/.env.global`, the file the socle loads into
every `gmake` run; `gmake env_global_enable` merges the pack's two lines into it
(`VPN_PROFILE=proton` and `VPN_KILL_SWITCH=true`). `gmake vpn_server` and the
kill switch targets write those lines, replacing them where they are. The boot
hook reads the same file, so what a target says and what the distro does cannot
disagree.

## The generated profile

`/etc/wireguard/vpn.conf` is **written at every mount** out of the JSON and the
two variables, then given to `wg-quick`. It is a derivative, not a file to read,
edit or hand to `wg-quick` yourself:

- **the interface is always `vpn`** — the kill switch's rules carry the
  interface's name, so a stable name is a stable rule;
- **it cannot be stale** — the boot hook goes through the same generator, so
  what comes up at a distro start is what the files say at that moment;
- **a hand correction is a correction to the generator** — `bin/vpn.sh` writes
  it, and the next `vpn_up` writes it again. If it is wrong, that is the bug to
  fix, and `vpn_status` shows what went into it.

## When it does not connect

`vpn_status` says the tunnel is up as soon as the interface is — which is not the
same as reaching the server. Two commands tell the two apart:

| What you see | What it means |
| :--- | :--- |
| `sudo wg show` shows no `latest handshake` line | The server never answered. The endpoint is the first suspect: Proton hands out an IPv4 address or an IPv6 one, and an instance with no IPv6 route can never reach an IPv6 endpoint. `ip -6 route show` says whether there is one — with none, take the IPv4 endpoint of the same server (`gmake vpn_edit_profiles`) |
| `vpn_status` says the exit IP is unreachable, handshake present | The traffic leaves but something eats it: the MTU (drop it to 1380 in the entry's `mtu`) or the kill switch on a machine whose traffic should partly stay local |
| no interface at all, `gmake vpn_up` failed | `wg-quick`'s own words are on screen, and `bin/vpn.sh up` prints them as they come |

## The DNS

`openresolv` owns `/etc/resolv.conf`, and the profile's `DNS = 10.2.0.1` is
applied when the tunnel comes up and released when it goes down — so
`gmake vpn_status` says where the names are resolved, tunnel up or down.

Two things this needs, both done by the install: `generateResolvConf = false` in
`/etc/wsl.conf` (otherwise WSL rewrites the file at every start), and
`openresolv` itself, which is not in Ubuntu 24.04's archive — the pack takes it
from Debian's package, and removes `systemd-resolved` first, because the two
claim the same `resolvconf` command.

### WSL does not give that file up on its own

`generateResolvConf = false` is what tells WSL to leave `/etc/resolv.conf`
alone, and **it is not enough**. Measured on an instance:

- WSL put its own symlink back — `/etc/resolv.conf → /mnt/wsl/resolv.conf` — at
  every start, and `/mnt/wsl` is a memory filesystem **shared by every distro of
  the machine**, so a fresh instance inherits whatever the last one wrote there;
- WSL answers the instance's DNS itself (`dnsTunneling`, its default), so **any
  nameserver resolves**: `10.2.0.1` with no tunnel, even an address nothing can
  answer on;
- and **deleting the file breaks name resolution completely** — glibc then falls
  back to `127.0.0.1`, inside the distro, where nothing listens.

Microsoft's own answer for that file being taken away is in
[microsoft/WSL#9070](https://github.com/microsoft/WSL/issues/9070); the usual
advice there, making it immutable with `chattr +i`, is not open to this pack —
the tunnel has to write it at every mount.

The lever is on the **Windows side**, in `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
dnsTunneling=false
```

then `wsl.exe --shutdown`. WSL stops answering for the instance and stops
touching the file: `/etc/resolv.conf` is the pack's, the base the install writes
is what the instance resolves with while the tunnel is down, and Proton's
`10.2.0.1` is what answers while it is up — checkable with `ip route get
10.2.0.1`, which says `dev vpn` when the tunnel is mounted.

The other instances are not disturbed: they keep resolving through the WSL
gateway, the way they did before (`nameserver 172.x.x.1` in their own file).
To go back: delete `%USERPROFILE%\.wslconfig` and run `wsl.exe --shutdown`
again.

One thing to know before applying it: that `wsl.exe --shutdown` restarts the
whole WSL machine, Docker Desktop's engine included, and Docker Desktop can be
left stuck on *Turning off the Docker Engine…* when its own distro is killed
under it — seen on this machine, and quitting the application does not clear
that state. Killing what is left of its processes does, from PowerShell:

```powershell
Get-Process | Where-Object { $_.Name -match 'docker' } | Stop-Process -Force
```

Nothing is lost — images, volumes and settings stay where they are. It was not
`dnsTunneling` that caused it: the engine stayed stuck with the setting disabled
too.

That file is written at install, and again by `vpn_up` before every mount —
`vpn_down` writes it too when it is missing and no tunnel is up. So an instance
that came back from a `wsl --shutdown` without one gets name resolution again
with `gmake vpn_down`, and `gmake vpn_auto_on` has the boot hook do it at every
start.

## The kill switch

`gmake vpn_ks_on` puts `VPN_KILL_SWITCH=true` in `.env.global`; the generated
profile then carries two `iptables` lines, `PostUp` and `PreDown`, that reject
anything not travelling through the tunnel. `gmake vpn_ks_off` takes them out
and remounts. To see it in place, with a tunnel up:

```bash
sudo iptables -S OUTPUT | head -3     # two REJECT lines, one per address family
```

The consequence, worth knowing before turning it on: while a tunnel is up,
services running **on Windows** and reached through the WSL gateway are rejected
too. Local destinations (loopback, WSLg, the Docker socket) are spared.

## Starting with the distro

`gmake vpn_auto_on` writes one line in `/etc/wsl.conf`:

```ini
[boot]
command=/usr/local/sbin/web-vpn-boot
```

That is WSL's own boot hook, not a systemd unit — see
[why below](#why-not-a-systemd-unit). It runs as root, finds the instance's user
in that same file, and calls the pack's script as that user, so the boot path is
the same code as `gmake vpn_up`: the profile is rebuilt, and the server started
is the one `VPN_PROFILE` names. It retries while the network comes up, always
exits, and writes what it did to `/var/log/web-vpn.log` — `vpn_status` shows the
last line of it.

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
stays), takes the generated `/etc/wireguard/vpn.conf` with it, and takes
`openresolv` back out — with the line to restore `systemd-resolved` if you want
it back.

What it leaves alone, on purpose: your servers in `~/.config/vpn/servers.json`
(your keys), the two `VPN_*` lines of `.env.global` (that file is the socle's),
the profiles an older install kept in `/etc/wireguard`, `generateResolvConf =
false` in `/etc/wsl.conf` (a machine setting, not the pack's), and Firefox's
profile in `~/.mozilla`.

A key that leaks is revoked **in your Proton account** (WireGuard → delete the
configuration): the server then refuses every new handshake. The entry on the
machine stops working, and nothing else needs undoing.
