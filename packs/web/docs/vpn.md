# The tunnel (WireGuard)

[← Back to the README](../../../README.md#optional-tooling) · [The pack](web.md)

A WireGuard tunnel inside the instance, driven by `gmake`, from the
configuration your provider gives you. No VPN client is involved: the profile
*is* the authentication.

It carries the traffic of this distro — Firefox, `curl`, `pip`, a `git push`. It
does not cover Windows, your other distros, or Docker Desktop.

## The targets

| Target | What it does |
| :--- | :--- |
| `vpn_status` | Up or down, the server, the kill switch, the DNS, the exit IP, what the distro starts with |
| `vpn_up [id]` | Connect. Naming a server — `gmake vpn_up VPN_PROFILE=NL72` — uses it for this call only |
| `vpn_up_from_list` | Connect, picking the server in a menu |
| `vpn_down` | Disconnect |
| `vpn_server [id]` | The server the distro starts with, and switch to it now if a tunnel is up |
| `vpn_ks_on` / `vpn_ks_off` | Put the kill switch in the tunnel, or take it out, and remount |
| `vpn_auto_on` / `vpn_auto_off` | Bring the tunnel up when the distro starts, or stop doing that |
| `vpn_edit_profiles` | Open the JSON of servers in `$EDITOR` (nano when unset), then pick the server |

`vpn_up`, `vpn_up_from_list` and `vpn_down` end on what `vpn_status` shows, and
wait for the server's first handshake before asking the exit IP. `wg-quick`'s own
trace is printed only when it fails.

## The servers

`~/.config/vpn/servers.json`, mode `600` — it carries your private keys, and the
pack never writes in it.

```json
{
  "id": "NL72",
  "note": "free server",
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
| `id` | The name the menus show and `VPN_PROFILE` carries: letters, digits, dot, dash, underscore |
| `address`, `private_key` | From the WireGuard configuration your provider hands you. Keep the IPv4 and the IPv6 address |
| `peer.*` | The server's key, its address, what goes through the tunnel |
| `note` | Yours |
| `dns`, `mtu`, `peer.persistent_keepalive` | Optional. Without them: `10.2.0.1`, `1420`, none |

Adding a server is one more entry in that file — there is no import command.

## The settings

| Variable | What it decides |
| :--- | :--- |
| `VPN_PROFILE` | The `id` of the server in use, and the one the distro starts with |
| `VPN_KILL_SWITCH` | `true`: the tunnel rejects what would leave outside it |

They live in `~/.config/zsh/gmake/.env.global`; `gmake vpn_server` and the kill
switch targets write them.

## The generated profile

`/etc/wireguard/vpn.conf` is written from the two files above before every mount.
Not a file to read or edit: the interface is always `vpn`, and a hand correction
is gone at the next mount. If it is wrong, what writes it is wrong.

## When it does not connect

| What you see | What it means |
| :--- | :--- |
| `sudo wg show` has no `latest handshake` line | The server never answered. The endpoint is the first suspect: the provider gives an IPv4 or an IPv6 address, and an instance with no IPv6 route cannot reach the second — `ip -6 route show` says whether there is one |
| the exit IP is unreachable, handshake present | The traffic leaves but something eats it: lower the MTU (`"mtu": "1380"` in the entry), or the kill switch on a machine whose traffic should partly stay local |
| no interface at all | `wg-quick`'s own words are on screen — they are printed when it fails |

## The DNS

`openresolv` owns `/etc/resolv.conf`: the profile's `DNS = 10.2.0.1` while the
tunnel is up, the base below it while it is down.

**WSL fights for that file.** It puts its own back at every start, even with
`generateResolvConf = false`, and it answers the instance's DNS itself — so any
nameserver resolves, and a missing file means no name resolution at all. To hand
the file back to the pack, in `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
dnsTunneling=false
```

**Stop Docker Desktop before the `wsl.exe --shutdown` that follows** — it does
not survive it well. Nothing else is disturbed, and deleting that file puts
everything back.

## The kill switch

`gmake vpn_ks_on` writes `VPN_KILL_SWITCH=true` and puts two `iptables` lines in
the profile; `vpn_ks_off` takes them out. To see them:

```bash
sudo iptables -S OUTPUT | head -3     # two REJECT lines, one per address family
```

While a tunnel is up, services running on Windows and reached through the WSL
gateway are rejected too.

## Starting with the distro

`gmake vpn_auto_on` writes this line in `/etc/wsl.conf`:

```ini
[boot]
command=/usr/local/sbin/web-vpn-boot
```

The hook runs at each start of the distro and raises the tunnel the way
`gmake vpn_up` does; what it did goes to `/var/log/web-vpn.log`, and
`vpn_status` shows the last line of it. WSL stops a distro shortly after its last
session closes, so "with the distro" means "whenever something starts it" — a
terminal, VS Code, Docker Desktop.

## Removing the pack

`.\wsl.ps1 remove_pack` takes the tunnel down, removes the hook, the packages and
`/etc/wireguard/vpn.conf`, and takes `openresolv` back out.

It leaves your servers, the `VPN_*` lines of `.env.global`, the profiles an older
install kept in `/etc/wireguard`, `generateResolvConf = false`, and `~/.mozilla`.

A key that leaks is revoked at your provider (delete that configuration): the
entry on the machine stops working, and nothing else needs
undoing.
