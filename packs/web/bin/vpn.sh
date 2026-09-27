#!/usr/bin/env bash
# ==============================================================================
# THE TUNNEL - WHAT THE gmake TARGETS CALL
# ==============================================================================
# The subcommands, one per target in make/vpn.mk, and one reason for the split:
# what needs a terminal (a menu) or a decision (which profile is up) lives here
# rather than inside a recipe, so each recipe stays one line and this file is
# read like any other shell script.
#
# The recipe is the user's own, written up in the pack's page: WireGuard profiles
# in /etc/wireguard, openresolv for the DNS, the kill switch inside the profile,
# and WSL's own boot hook for the automatic start (not a systemd unit - see
# bin/vpn-boot.sh).
#
# Nothing here writes to a profile: the keys are the user's. What this script
# owns is which profile the distro starts with, and nothing else.

set -euo pipefail

WG_DIR=/etc/wireguard
MARKER=$WG_DIR/auto
BOOT_SCRIPT=/usr/local/sbin/web-vpn-boot
BOOT_LOG=/var/log/web-vpn.log
HOOK="command=$BOOT_SCRIPT"
WSLCONF=/etc/wsl.conf

here=$(cd "$(dirname "$0")" && pwd)

die() {
    printf '❌ %s\n' "$*" >&2
    exit 1
}

# The profiles, without the .conf suffix. The directory is root-only (mode 700),
# so the listing goes through sudo - and the reading happens on this side of the
# pipe: what comes back is a list of names, not a directory handle.
profiles() {
    sudo ls -1 "$WG_DIR" 2>/dev/null | sed -n 's/\.conf$//p' | sort || true
}

# The interface that is up, or nothing at all. wg-quick names the interface after
# the profile, so this is also the name of the profile in use.
# `|| true` on both: when the tools are gone (a removal that stopped half way)
# sudo fails, pipefail makes the pipeline fail, and a caller under `set -e`
# would stop on a question it merely could not answer.
active() {
    sudo wg show interfaces 2>/dev/null | awk 'NR == 1 { print; exit }' || true
}

# Does that profile exist? Asked as root, for the same reason as the listing.
has_profile() {
    sudo test -f "$WG_DIR/$1.conf"
}

# The name of a profile is the name of its file, and wg-quick takes the file's
# name as the interface's - and Linux refuses an interface name longer than 15
# characters. Anything that would need quoting is refused with it, and so is
# `auto`: that one is the marker the boot hook reads, and a profile by that name
# would be two files fighting over one path.
valid_profile_name() {
    case "$1" in
    "" | auto | *[!a-zA-Z0-9_-]* | ????????????????*) return 1 ;;
    esac
    return 0
}

# The menu. fzf, like the other pickers of this shell (fcheat, fnew), and the
# whole list on screen: three servers do not need a scrolling window.
# It needs a terminal, and says which way round that is: a menu cannot be
# answered from a pipe or a script, and the profile can be named instead.
pick() {
    local choice
    if ! choice=$(profiles | fzf --prompt="$1 > " --info=inline --layout=reverse); then
        die "no server chosen - a menu needs a terminal. Name one instead: gmake <target> VPN_PROFILE=<name>"
    fi
    [ -n "$choice" ] || die "no server chosen."
    printf '%s\n' "$choice"
}

# Is the distro told to start the tunnel? The marker says which profile, the
# [boot] line says that anything is started at all.
hook_present() {
    sudo grep -qxF "$HOOK" "$WSLCONF" 2>/dev/null
}

# Both are written idempotently: turning the automatic start on twice leaves one
# line and one marker, and the boot script is replaced by the pack's own copy.
# The line goes under [boot] and nowhere else - /etc/wsl.conf is also where the
# install wrote generateResolvConf, and rewriting the file whole would take that
# with it.
hook_on() {
    sudo install -m 0755 "$here/vpn-boot.sh" "$BOOT_SCRIPT"
    if hook_present; then
        return 0
    fi
    if sudo grep -q '^\[boot\]' "$WSLCONF" 2>/dev/null; then
        sudo sed -i "\|^\[boot\]|a $HOOK" "$WSLCONF"
    else
        printf '\n[boot]\n%s\n' "$HOOK" | sudo tee -a "$WSLCONF" > /dev/null
    fi
    hook_present || die "the [boot] line could not be written to $WSLCONF"
}

hook_off() {
    if sudo test -f "$WSLCONF"; then
        sudo sed -i "\|^${HOOK}$|d" "$WSLCONF"
    fi
    sudo rm -f "$BOOT_SCRIPT"
}

cmd_status() {
    local up ns exit_ip starts last

    up=$(active)
    if [ -n "$up" ]; then
        printf '🔒 Tunnel      : up (%s)\n' "$up"
    else
        printf '⚪ Tunnel      : down\n'
    fi

    printf '   Profiles    : %s\n' "$(profiles | paste -sd' ' - || echo 'none')"

    ns=$(sed -n 's/^nameserver[[:space:]]\+//p' /etc/resolv.conf | head -n 1)
    printf '   DNS         : %s\n' "${ns:-none}"

    exit_ip=$(curl -s --max-time 8 https://am.i.mullvad.net/ip 2>/dev/null || true)
    printf '   Exit IP     : %s\n' "${exit_ip:-unreachable}"

    if hook_present; then
        starts=$(sudo cat "$MARKER" 2>/dev/null || true)
        printf '   Starts with : the distro, profile %s\n' "${starts:-?}"
    else
        printf '   Starts with : nothing (gmake vpn_auto_on turns it on)\n'
    fi

    last=$(sudo tail -n 1 "$BOOT_LOG" 2>/dev/null || true)
    [ -n "$last" ] && printf '   Last start  : %s\n' "$last"
    return 0
}

# Connect, now. Without a name, the menu decides - and when a profile is already
# up and another is wanted, this is also the switch: down first, up after.
cmd_up() {
    local wanted current
    wanted=${1:-}
    if [ -z "$wanted" ]; then
        wanted=$(pick "VPN server") || die "no server chosen - nothing was started."
    fi
    has_profile "$wanted" || die "no profile '$wanted' in $WG_DIR"

    current=$(active)
    if [ "$current" = "$wanted" ]; then
        printf 'ℹ️  %s is already up.\n' "$wanted"
        return 0
    fi
    if [ -n "$current" ]; then
        printf '⤵️  %s down\n' "$current"
        sudo wg-quick down "$current"
    fi
    sudo wg-quick up "$wanted"
    printf '✅ %s is up.\n' "$wanted"
}

cmd_down() {
    local current
    current=$(active)
    if [ -z "$current" ]; then
        printf 'ℹ️  no tunnel is up.\n'
        return 0
    fi
    sudo wg-quick down "$current"
    printf '✅ %s is down.\n' "$current"
}

# The default: the server the distro starts with. It switches to it right away
# when a tunnel is up, so "the server I chose" and "the server I am on" do not
# disagree until the next restart.
cmd_server() {
    local wanted current
    wanted=${1:-}
    if [ -z "$wanted" ]; then
        wanted=$(pick "The server the distro starts with") || die "no server chosen - nothing was changed."
    fi
    has_profile "$wanted" || die "no profile '$wanted' in $WG_DIR"

    printf '%s\n' "$wanted" | sudo tee "$MARKER" > /dev/null
    printf '✅ %s is the server the distro starts with.\n' "$wanted"

    current=$(active)
    if [ -n "$current" ] && [ "$current" != "$wanted" ]; then
        sudo wg-quick down "$current"
        sudo wg-quick up "$wanted"
        printf '🔁 Switched to %s now.\n' "$wanted"
    fi

    if ! hook_present; then
        printf 'ℹ️  The automatic start is off - gmake vpn_auto_on turns it on.\n'
    fi
}

# A new profile starts from the pack's sample, so the four lines nobody
# remembers - the address, the resolver, the MTU, the kill switch - are already
# there and only the two keys and the peer are to paste. It is never written
# over a profile that exists: that file carries a private key, and replacing it
# silently is the one move this pack does not make.
cmd_profile_add() {
    local name=${1:-} editor
    [ -n "$name" ] || die "which profile? gmake vpn_profile_add VPN_PROFILE=<name>"
    valid_profile_name "$name" ||
        die "'$name' cannot be a profile name: 15 characters at most, letters, digits, - and _ (it becomes both a file name and an interface name)."

    if has_profile "$name"; then
        printf 'ℹ️  %s already exists - opening it, nothing was written.\n' "$WG_DIR/$name.conf"
    else
        sudo install -d -m 0700 "$WG_DIR"
        sudo install -m 600 "$here/../vpn.conf.sample" "$WG_DIR/$name.conf"
        printf '📝 %s was created from the sample: the MTU and the kill switch are in it.\n' "$WG_DIR/$name.conf"
        printf '   Paste your private key, the address, and the [Peer] block - then save.\n'
    fi

    # The editor is yours: $EDITOR when it is set (one command, no arguments),
    # nano otherwise - nano is in the image, and it is what the cheatsheets
    # already use for a profile.
    editor=${EDITOR:-nano}
    sudo "$editor" "$WG_DIR/$name.conf"

    if sudo test -s "$WG_DIR/$name.conf"; then
        printf '✅ %s is in place - gmake vpn_up offers it.\n' "$name"
    else
        printf '⚠️  %s is empty: gmake vpn_up will refuse it.\n' "$WG_DIR/$name.conf"
    fi
}

# Removing one takes the tunnel down first when it is the one that is up:
# wg-quick needs the file to undo the addresses and the routes it added, and the
# file is what is about to go.
cmd_profile_remove() {
    local name=${1:-} current
    [ -n "$name" ] || die "which profile? gmake vpn_profile_remove VPN_PROFILE=<name>"
    has_profile "$name" || die "no profile '$name' in $WG_DIR"

    current=$(active)
    if [ "$current" = "$name" ]; then
        sudo wg-quick down "$name"
        printf '⤵️  %s was up: it is down.\n' "$name"
    fi

    sudo rm -f "$WG_DIR/$name.conf"
    printf '✅ %s is gone.\n' "$name"

    if [ "$(sudo cat "$MARKER" 2>/dev/null || true)" = "$name" ]; then
        printf '⚠️  It was the profile the distro starts with.\n'
        printf '    Pick another with gmake vpn_server, or the boot hook will only say so in %s.\n' "$BOOT_LOG"
    fi
}

cmd_auto() {
    local what wanted
    what=${1:-}
    case "$what" in
    on)
        wanted=${2:-}
        if [ -z "$wanted" ]; then
            wanted=$(active)
        fi
        if [ -z "$wanted" ]; then
            wanted=$(pick "The server the distro starts with") || die "no server chosen - nothing was changed."
        fi
        has_profile "$wanted" || die "no profile '$wanted' in $WG_DIR"

        printf '%s\n' "$wanted" | sudo tee "$MARKER" > /dev/null
        hook_on
        printf '✅ The tunnel will come up with the distro, profile %s.\n' "$wanted"
        printf '   Nothing happens now: it is the next start of the distro that runs it.\n'
        ;;
    off)
        hook_off
        sudo rm -f "$MARKER"
        printf '✅ The distro will not bring the tunnel up.\n'
        printf '   A tunnel that is up right now stays up - gmake vpn_down takes it down.\n'
        ;;
    *)
        die "auto takes 'on' or 'off'"
        ;;
    esac
}

case "${1:-}" in
status)
    shift
    cmd_status "$@"
    ;;
up)
    shift
    cmd_up "$@"
    ;;
down)
    shift
    cmd_down "$@"
    ;;
profile_add)
    shift
    cmd_profile_add "$@"
    ;;
profile_remove)
    shift
    cmd_profile_remove "$@"
    ;;
server)
    shift
    cmd_server "$@"
    ;;
auto)
    shift
    cmd_auto "$@"
    ;;
*)
    cat <<'USAGE'
usage: vpn.sh <command>

  status              the tunnel, the profiles, the DNS, the exit IP, and what
                      the distro starts with
  up [profile]        connect now - the menu decides when no profile is named
  down                disconnect
  server [profile]    the server the distro starts with (and switch to it now)
  auto on [profile]   bring the tunnel up with the distro
  auto off            stop doing that
  profile_add <name>  create a profile from the pack's sample, then edit it
  profile_remove <name>  delete one (the caller asks first)

Every command is a gmake target of the same name: gmake vpn_status, vpn_up,
vpn_down, vpn_server, vpn_auto_on, vpn_auto_off, vpn_profile_add,
vpn_profile_remove.
USAGE
    exit 2
    ;;
esac
