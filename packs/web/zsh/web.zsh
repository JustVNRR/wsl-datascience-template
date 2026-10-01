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

# Firefox asks for a session bus before it draws anything, and this image has
# none: no dbus-daemon, no dbus-launch, and the report is the same everywhere -
# the first window never opens, the second one does. dbus-x11 is part of the
# pack for that reason, and this is the other half: the first `fox` of a shell
# starts a bus for that shell, and every later call finds the variable already
# set and runs the plain command.
fox() {
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

# One word for the browser the pack hardens, in private: the privacy defaults
# first, the private window after. The defaults are only written when they are
# not already the pack's copy (fox.sh compares before it writes), so the usual
# call asks for no password and answers one line - and `gmake fox_tweak_off`
# still takes the file away, the next `pfox` putting it back.
pfox() {
    gmake fox_tweak_on || return
    fox --private-window "$@"
}
