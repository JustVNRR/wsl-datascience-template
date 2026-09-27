# ============================================================
# THE BROWSER
# ============================================================
# This file is the pack's: the socle reads it where it lives
# (~/.config/packs/web/zsh/web.zsh) and copies nothing anywhere - a pack that
# goes takes its shell configuration with it.

# Firefox asks for a session bus before it draws anything, and this image has
# none: no dbus-daemon, no dbus-launch, and the report is the same everywhere -
# the first window never opens, the second one does. dbus-x11 is part of the
# pack for that reason, and this is the other half: the first `fox` of a shell
# starts a bus for that shell, and every later call finds the variable already
# set and runs the plain command.
fox() {
    if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]] && command -v dbus-launch >/dev/null 2>&1; then
        eval "$(dbus-launch --sh-syntax)"
    fi
    firefox "$@"
}
