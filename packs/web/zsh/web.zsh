# ============================================================
# THE BROWSER
# ============================================================
# This file is the pack's: the socle reads it where it lives
# (~/.config/packs/web/zsh/web.zsh) and copies nothing anywhere - a pack that
# goes takes its shell configuration with it.

# Wayland or X11: Firefox picks Wayland when the machine announces it, and WSLg
# announces it - which is the wrong half of the pair under WSL, where it is the
# Wayland path that misbehaves (scrolling, menus that stop answering, frames
# dropped). X11, which WSLg also serves through XWayland, behaves.
#
# Set here rather than in a profile of its own, so both ways in are covered:
# `fox` and plain `firefox`. One call can ask for Wayland back:
# `MOZ_ENABLE_WAYLAND=1 fox`.
export MOZ_ENABLE_WAYLAND=0

# The pack's root and script, from this file's own path - %x is where a
# function here was defined (inside one, $0 is the function's name).
PACK=${${(%):-%x}:A:h:h}
FOX_SH=$PACK/bin/fox.sh

# What both launchers end on, and the bus Firefox asks for before it draws
# anything - this image has none (no dbus-daemon, no dbus-launch), and the
# report is the same everywhere: the first window never opens, the second one
# does. dbus-x11 is part of the pack for that reason, and this is the other
# half: the first launch of a shell starts a bus for that shell, and every
# later call finds the variable already set and runs the plain command.
_fox_launch() {
    if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]] && command -v dbus-launch >/dev/null 2>&1; then
        # The bus refuses the runtime directory WSLg hands the shell -
        # /mnt/wslg/runtime-dir is world-writable, and dbus says so at every
        # first launch ("can be written by others"). It gets one of its own
        # for this call; the shell keeps WSLg's, which Wayland and the sound
        # reach through.
        install -d -m 0700 "$HOME/.run"
        eval "$(XDG_RUNTIME_DIR="$HOME/.run" dbus-launch --sh-syntax)"
    fi
    firefox "$@"
}

# fox opens the browser on the light privacy settings - and puts them back if
# the previous visit was a strict one. The launcher chooses the set, because
# the settings are read as Firefox starts (docs/fox.md).
fox() {
    "$FOX_SH" light || return
    _fox_launch "$@"
}

# pfox opens the private window on the strict settings, with the pack's check
# page first - what the browser actually does, measured live
# (privacy-check.html, filled with the set and the DNS resolver read here).
# The switch counts at Firefox's next start, so a switch while it runs would
# be silently wrong - a "strict" pfox opening a light session - and pfox
# refuses instead.
pfox() {
    if pgrep -x firefox >/dev/null 2>&1; then
        print -u2 "Firefox is already running - close it, then run pfox again (the settings count at its next start)."
        return 1
    fi
    "$FOX_SH" strict || return
    local dns
    dns=$(awk '/^[[:space:]]*nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null)
    _fox_launch --private-window "file://$PACK/privacy-check.html#strict;dns=$dns" "$@"
}
