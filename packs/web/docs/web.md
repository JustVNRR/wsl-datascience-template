# Web browser and tunnel

[← Back to the README](../../../README.md#optional-tooling)

A browser inside the instance — its window lands on the Windows desktop through
WSLg — and the tunnel its traffic can go through.

| Piece | For | Commands |
| :--- | :--- | :--- |
| Firefox | browsing, from inside the instance | `firefox` |
| the launchers | the session bus the image lacks; light set with `fox`, strict with `pfox` | `fox`, `pfox` |
| the privacy sets | switchable by hand too | `fox_tweak_on`, `fox_tweak_off` |
| the tunnel | the traffic, through your own WireGuard server | [the tunnel's page](vpn.md) |

## Installing and removing it

```powershell
.\wsl.ps1 add_pack      # pick the instance, then web
.\wsl.ps1 remove_pack   # the reverse
```

The commands arrive with the pack's folder and show up in the picker
(`Alt + z`). On removal, a package another installed pack still claims stays
in place.

## Firefox

**From Mozilla's repository**, not Ubuntu's archive: 24.04's `firefox` package
installs the snap. The pack registers Mozilla's key (fingerprint checked),
their source, and a pin that keeps the stub out; removal takes it all back.

**`fox` and `pfox` open it with a session bus.** The image has no dbus, and
Firefox without one never opens its first window. The first launch of a shell
starts the bus; plain `firefox` works afterwards too.

**X11, not Wayland**: WSLg announces Wayland, and that path misbehaves under
WSL (scrolling, menus that stop answering, dropped frames).
`MOZ_ENABLE_WAYLAND=1 fox` asks for it back for one call. Which one is in use:
`about:support`, *Window Protocol*.

**The sound goes through PulseAudio**, which is how WSLg carries a Linux
window's audio to Windows. Two pieces: the client library the browser loads at
runtime (`libpulse0`), and a default preference letting it reach the socket
WSLg serves — `media.cubeb.sandbox=false`, in
`/usr/lib/firefox/defaults/pref/wslg-audio.js` (a default: `about:config`
wins; removal takes it back).

The volume is the instance's own, not Windows': `sudo apt install
pulseaudio-utils`, then

| Command | What it does |
| :--- | :--- |
| `pactl get-sink-volume @DEFAULT_SINK@` | The level |
| `pactl set-sink-volume @DEFAULT_SINK@ 50%` | Set it (`+10%` / `-10%` steps) |
| `pactl set-sink-mute @DEFAULT_SINK@ toggle` | Cut it, and bring it back |
| `pactl list sinks short` | What WSLg offers (one output) |

The output device is chosen in Windows — Settings → System → Sound, before the
distro starts.

**A live stream answers "your browser can't play this video"?** Live streams
arrive in H.264/AAC, which the browser asks the system for; the pack installs
that decoder (`libavcodec60`). Ordinary videos (VP9/AV1) never need it.

**The privacy settings** come in two sets, and the launcher picks: `fox` light,
`pfox` strict, with the check page first. A switch costs no password; `pfox`
refuses while Firefox is running (the settings count at the next start).
`fox_tweak_on` / `fox_tweak_off` are the manual switches. What each set holds:
[the privacy page](fox.md).

Your profile (`~/.mozilla`) is yours: removal does not delete it.

## The tunnel

WireGuard, from the profile your provider gives you, with the kill switch, the
DNS through `openresolv`, and the choice of what starts with the distro:
[the tunnel's page](vpn.md).
