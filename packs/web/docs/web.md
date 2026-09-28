# Web browser and tunnel

[← Back to the README](../../../README.md#optional-tooling)

A browser inside the instance, and the tunnel its traffic can go through. The
window appears on the Windows desktop through WSLg, like any other Linux
graphical application — nothing is displayed inside the terminal.

| Piece | For | Commands |
| :--- | :--- | :--- |
| Firefox | browsing, from inside the instance | `firefox` |
| the pack's function | opening it with the session bus the image does not have | `fox` |
| the tunnel | the traffic, through your own Proton profile | [the tunnel's page](vpn.md) |

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
after that is the plain command, and `firefox` works on its own too. If the
mouse misbehaves under Wayland, `MOZ_ENABLE_WAYLAND=0 fox` forces X11 — the pack
does not set it, because on most machines it is not needed.

**Its sound goes through PulseAudio**, which is how WSLg carries the audio of a
Linux window to the Windows output device — and Mozilla's package only pulls the
ALSA library, so the pack installs `libpulse0` too. Without it the browser opens,
plays, and stays mute. Which device it comes out of is not decided here: WSLg
plays on the **Windows default output**, so the choice is in Windows (Settings →
System → Sound), made before the distro starts — a headset connected afterwards
is usually not followed until WSL restarts (`wsl.exe --shutdown`).

Your profile (`~/.mozilla`: bookmarks, passwords, history) is yours: removing
the pack does not delete it.

## The tunnel

WireGuard, from the profile Proton gives your account, with the kill switch, the
DNS through `openresolv`, and the choice of what starts with the distro:
[the tunnel's page](vpn.md).
