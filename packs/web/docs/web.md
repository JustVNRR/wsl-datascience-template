# Web browser and tunnel

[← Back to the README](../../../README.md#optional-tooling)

A browser inside the instance, and the tunnel its traffic can go through. The
window appears on the Windows desktop through WSLg, like any other Linux
graphical application — nothing is displayed inside the terminal.

| Piece | For | Commands |
| :--- | :--- | :--- |
| Firefox | browsing, from inside the instance | `firefox` |
| the pack's function | opening it with the session bus the image does not have | `fox` |
| the private launcher | a private window, on the strict privacy set | `pfox` |
| the privacy sets | light with `fox`, strict with `pfox`; manual switches when needed | `fox_tweak_on`, `fox_tweak_off` |
| the tunnel | the traffic, through your own WireGuard profile | [the tunnel's page](vpn.md) |

## Installing and removing it

```powershell
.\wsl.ps1 add_pack      # pick the instance, then web
.\wsl.ps1 remove_pack   # the reverse
```

The commands arrive with the pack's folder, and show up in the cheatsheet
picker (`Alt + z`) as soon as the pack is installed. On removal, a package that
**another installed pack still claims** stays where it is — that is what makes
removing one pack safe when two of them share something.

## Firefox

**It comes from Mozilla's own repository**, not from Ubuntu's archive: on Ubuntu
24.04 the `firefox` package is a transitional one that installs the snap, and
snap inside WSL is a route worth avoiding. The pack registers Mozilla's key
(fingerprint checked), their source, and a pin that keeps the transitional
package out for good — and removing the pack takes all of it back.

**`fox` opens it with a session bus**, which is the whole reason it is a
function rather than an alias: the image has no `dbus-daemon` and no
`dbus-launch`, and Firefox without one never opens its **first** window (the
second one works).

```zsh
fox() {
    if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]] && command -v dbus-launch >/dev/null 2>&1; then
        eval "$(dbus-launch --sh-syntax)"
    fi
    firefox "$@"
}
```

The first `fox` of a shell starts a bus and leaves the variable set; every call
after that is the plain command, and `firefox` works on its own too.

**It runs on X11, and that is the pack's choice**: Firefox takes Wayland when
the machine announces it, WSLg announces it, and under WSL the Wayland path is
the one that misbehaves — scrolling, menus that stop answering, frames dropped.
`web.zsh` exports `MOZ_ENABLE_WAYLAND=0`, so the two ways in (`fox` and plain
`firefox`) behave the same; `MOZ_ENABLE_WAYLAND=1 fox` asks for Wayland back for
one call, or a line in `~/.zshrc` makes it permanent. Which one is in use is in
`about:support`, under *Window Protocol*.

**Its sound goes through PulseAudio**, which is how WSLg carries the audio of a
Linux window to Windows — and Mozilla's package only pulls the ALSA library. Two
things the pack puts in place for it:

- the client library the browser loads at runtime (`libpulse0`), without which
  it opens, plays, and stays mute;
- a default preference that lets it reach the socket WSLg serves, in
  `/usr/lib/firefox/defaults/pref/wslg-audio.js`:

  ```js
  pref("media.cubeb.sandbox", false);
  ```

That file is a *default*, not an order: it applies to every profile — no name to
guess — and a value set in `about:config` wins over it. Removing the pack takes
it back.

**The volume is its own**, and it is not the one Windows shows: WSLg plays the
sound itself, so turning the Windows volume down does not turn this one down.
Setting it needs a client tool, which the pack does not install —
`sudo apt install pulseaudio-utils`, and then:

| Command | What it does |
| :--- | :--- |
| `pactl get-sink-volume @DEFAULT_SINK@` | The level it is playing at |
| `pactl set-sink-volume @DEFAULT_SINK@ 50%` | Set it — `+10%` / `-10%` for a step |
| `pactl set-sink-mute @DEFAULT_SINK@ toggle` | Cut it, and bring it back |
| `pactl list sinks short` | The output WSLg offers (one: its own) |

**Which device it comes out of is decided in Windows**, not here: WSLg plays on
the Windows default output, so the choice is in Settings → System → Sound,
*made before the distro starts* — a headset connected afterwards is usually not
followed until WSL restarts (`wsl.exe --shutdown`).

**Videos play, live streams do not?** YouTube sends H.264 and AAC for its live
streams, where ordinary videos arrive in VP9/AV1 — and the browser decodes those
two itself but asks the system for H.264. The pack installs that decoder
(`libavcodec60`) with the browser; a hand-built instance can be missing it, and
then a live stream answers *"your browser can't play this video"* while
everything else plays.

**The privacy settings come in two sets, and the launcher picks**: `fox` opens
on the light set, `pfox` opens a private window on the strict one — the
settings are read as Firefox starts. The install leaves the light set in
place; a switch costs no password, because the browser's directory holds a
link to a file of your own; and `pfox` refuses to launch while Firefox is
already running, since a switch would count only at the next start.
`gmake fox_tweak_on` / `fox_tweak_off` are the manual switches. What each set
holds: [the privacy page](fox.md).

Your profile (`~/.mozilla`: bookmarks, passwords, history) is yours: removing
the pack does not delete it.

## The tunnel

WireGuard, from the profile your provider gives you, with the kill switch, the
DNS through `openresolv`, and the choice of what starts with the distro:
[the tunnel's page](vpn.md).
