#!/usr/bin/env bash
# ==============================================================================
# THE TUNNEL - WHAT THE gmake TARGETS CALL
# ==============================================================================
# The subcommands, one per target in make/vpn.mk, and one reason for the split:
# what needs a terminal (a menu) or a decision (which server is up) lives here
# rather than inside a recipe, so each recipe stays one line and this file is
# read like any other shell script.
#
# Three files hold this half of the pack:
#
#   ~/.config/vpn/servers.json    your servers: one entry per Proton server, with
#                                 its own keys. Yours - the pack seeds it from
#                                 its sample, and never writes in it again.
#   ~/.config/zsh/gmake/.env.global
#                                 VPN_PROFILE (the server to use, and the one the
#                                 distro starts with) and VPN_KILL_SWITCH. The
#                                 socle loads this file into every gmake run, and
#                                 `gmake env_global_enable` merges the pack's two
#                                 lines into it.
#   /etc/wireguard/vpn.conf       NOT yours, and not a file anyone edits: it is
#                                 written here, out of the two above, right
#                                 before every mount. The interface is therefore
#                                 always `vpn` - which is what keeps the kill
#                                 switch's rules stable (they carry %i).
#
# The boot hook goes through this same file (bin/vpn-boot.sh), so the profile
# cannot be stale at the moment it is used: it is rebuilt at every start too.
#
# The recipe is the user's own, written up in the pack's page: WireGuard profiles
# over openresolv for the DNS, the kill switch as two iptables lines, and WSL's
# own boot hook for the automatic start (not a systemd unit - see vpn-boot.sh).

set -euo pipefail

WG_DIR=/etc/wireguard
IFACE=vpn
CONF=$WG_DIR/$IFACE.conf
BOOT_SCRIPT=/usr/local/sbin/web-vpn-boot
BOOT_LOG=/var/log/web-vpn.log
HOOK="command=$BOOT_SCRIPT"
WSLCONF=/etc/wsl.conf

here=$(cd "$(dirname "$0")" && pwd)
SAMPLE=$here/../vpn.servers.sample

# The user's files, under $HOME - and $HOME is the instance's user both when a
# gmake target runs this and when the boot hook does: the hook finds that user
# and hands it over before calling (see bin/vpn-boot.sh).
SERVERS=$HOME/.config/vpn/servers.json
GLOBAL_ENV=$HOME/.config/zsh/gmake/.env.global

# The DNS and the MTU are constants of the generator, not variables: they are the
# same for every Proton server, and duplicating them in each entry would be four
# lines to keep in step. An entry may carry "dns" or "mtu" of its own - a server
# that needs another value wins - and then it is written here. The peer's
# "persistent_keepalive" is the same arrangement: nothing by default, and a
# number in an entry when that server needs one.
DNS_DEFAULT=10.2.0.1
MTU_DEFAULT=1420

# The resolver the install writes, and the one vpn_down puts back when it finds
# the file gone. Kept here so the two are the same value, said once.
DNS_BASE=1.1.1.1

# The kill switch: two iptables lines, in the generated profile, that reject
# whatever would leave outside the tunnel. The mark is the one wg-quick puts on
# its own packets, and LOCAL destinations (loopback, WSLg, the Docker socket) are
# spared - without that last part, the terminal this was typed in would go quiet
# first. The $( ) below belongs to wg-quick: it is expanded when the tunnel comes
# up, not here.
# shellcheck disable=SC2016
KS_UP='iptables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT && ip6tables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT'
# shellcheck disable=SC2016
KS_DOWN='iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT && ip6tables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT'

die() {
    printf '❌ %s\n' "$*" >&2
    exit 1
}

# Privileged work, and it has to work both ways round: a gmake target runs this
# as the instance's user (sudo, and its password prompt), and the boot hook runs
# it as root, where sudo would be one indirection too many.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# The files below are the user's, and $HOME is what says which user. Started as
# root with root's own home - `sudo vpn.sh up`, which is not how this is called -
# it would read /root/.config and answer for nobody. The boot hook sets HOME
# before calling, so it is not concerned by this.
if [ "$(id -u)" -eq 0 ] && [ "${HOME:-}" = /root ]; then
    die "this reads your own files: run it as yourself (gmake vpn_up), not through sudo."
fi

# --- the JSON of servers ------------------------------------------------------

# jq reads it, and nothing greps inside it: a structured file is read by a tool
# that knows the structure, and one that does not parse is an error with a line
# number rather than a wrong value. jq is in the image, like the rest of what
# this pack leans on.
json_ok() {
    [ -f "$SERVERS" ] && jq -e . "$SERVERS" > /dev/null 2>&1
}

# Every id, one per line, in the file's order: what the menus show, and what the
# composer looks a server up by.
ids() {
    [ -f "$SERVERS" ] || return 0
    jq -r '(.servers // [])[] | .id // empty' "$SERVERS" 2>/dev/null || true
}

# One field of one entry, empty when the entry has none. Two functions rather
# than one, because the peer's fields are one level down and that is the whole
# difference.
field() {
    jq -r --arg id "$1" --arg k "$2" '(.servers // [])[] | select(.id == $id) | .[$k] // empty' "$SERVERS" 2>/dev/null || true
}

peer_field() {
    jq -r --arg id "$1" --arg k "$2" '(.servers // [])[] | select(.id == $id) | (.peer // {})[$k] // empty' "$SERVERS" 2>/dev/null || true
}

# How many entries carry that id. It has to be exactly one: two entries with the
# same id are two answers to one question, and the composer would write one of
# them without saying which.
entries() {
    jq -r --arg id "$1" '[ (.servers // [])[] | select(.id == $id) ] | length' "$SERVERS" 2>/dev/null || printf '0'
}

# What an id may be. It names a server in the menus, and it is written into
# .env.global, where make reads it: a space would be trimmed, a `#` would cut the
# line short and an `=` would end the name. So letters, digits, dot, dash,
# underscore - and no length limit any more, since it is no longer an interface
# name (the interface is `vpn`, always).
VALID_ID='^[A-Za-z0-9._-]+$'
valid_id() {
    printf '%s' "$1" | grep -qE "$VALID_ID"
}

# Are every id of the file usable, and each of them once? Asked after the editor
# closed on it: the file is the user's, and this is what a menu and a variable
# can carry.
check_ids() {
    local id seen=
    while read -r id; do
        [ -n "$id" ] || continue
        if ! valid_id "$id"; then
            printf '⚠️  id "%s" is not usable: letters, digits, dot, dash and underscore only.\n' "$id" >&2
            printf '   It is shown in the menus and written into .env.global, where a space or a # would not survive.\n' >&2
            return 1
        fi
        case " $seen " in
        *" $id "*)
            printf '⚠️  id "%s" appears twice - one entry per server.\n' "$id" >&2
            return 1
            ;;
        esac
        seen="$seen $id"
    done < <(ids)
    return 0
}

# --- the two variables --------------------------------------------------------

# Read from .env.global, never from the environment this was started with. A make
# target hands a value down by naming it on the command line, and the recipe
# passes it as an argument; reading the exported copy here would answer with what
# .env.global held when make started - the one stale answer these two files exist
# to avoid.
env_var() {
    local name=$1 line
    [ -r "$GLOBAL_ENV" ] || return 0
    line=$(grep -E "^[[:space:]]*$name=" "$GLOBAL_ENV" | tail -n 1 || true)
    printf '%s\n' "${line#*=}"
}

server_var() {
    env_var VPN_PROFILE
}

ks_on() {
    case "$(env_var VPN_KILL_SWITCH)" in
    true | TRUE | True | yes | 1) return 0 ;;
    *) return 1 ;;
    esac
}

# What the kill switch reads as, in one line, for vpn_status and for the message
# a mount ends with.
ks_line() {
    if [ ! -r "$GLOBAL_ENV" ]; then
        printf 'off (no %s yet - gmake env_global_enable builds it)\n' "$GLOBAL_ENV"
    elif ks_on; then
        printf 'on\n'
    else
        printf 'off (%s)\n' "$(env_var VPN_KILL_SWITCH)"
    fi
}

# Writing one of the two variables. That file is the socle's - make reads it, and
# `gmake env_global_enable` fills it in from the samples - so this writes one
# line of it and nothing else: the line is replaced where it is, or appended when
# the variable is not there yet (which is what a machine that never ran
# env_global_enable looks like). The value is an id, checked by valid_id before
# this is called, or the literal true/false: no byte of either needs escaping.
write_env() {
    local name=$1 value=$2
    [ -f "$GLOBAL_ENV" ] || die "no $GLOBAL_ENV yet - 'gmake env_global_enable' builds it from the samples."
    if grep -qE "^[[:space:]]*$name=" "$GLOBAL_ENV"; then
        sed -i -E "s|^[[:space:]]*$name=.*|$name=$value|" "$GLOBAL_ENV"
    else
        printf '\n%s=%s\n' "$name" "$value" >> "$GLOBAL_ENV"
    fi
    printf '📝 %s=%s (%s)\n' "$name" "$value" "$GLOBAL_ENV"
}

# --- the tunnel ---------------------------------------------------------------

# Is a tunnel up? wg-quick names the interface after the file it read, and the
# file is always vpn.conf - so the question is one comparison.
is_up() {
    [ "$(as_root wg show interfaces 2>/dev/null | head -n 1)" = "$IFACE" ]
}

# wg-quick tells what it does, line by line - `[#] ip link add vpn`, `[#] ip -4
# route add ...` - and that is worth reading the day something goes wrong, and
# noise the rest of the time. So it is captured, and given back only when it
# fails: the one moment its words are the answer.
run_quiet() {
    local out
    if ! out=$("$@" 2>&1); then
        printf '%s\n' "$out" >&2
        return 1
    fi
}

# Which server is up? The interface is always `vpn`, so nothing at the interface
# level remembers it - but the profile does: its second line names the server it
# was generated for, and it is written right before every mount. Empty when no
# tunnel is up, or when the file is not the pack's.
server_in_use() {
    is_up || return 0
    as_root sed -n 's/^# Server: \([^ ]*\).*/\1/p' "$CONF" 2>/dev/null | head -n 1 || true
}

# The tunnel comes up before the server has answered anything: wg-quick sets the
# interface and its routes, and the handshake happens afterwards. Asking the
# exit IP in that instant answers "unreachable" about a tunnel that is perfectly
# fine - so wait for the first handshake, a second at a time, and say so when it
# never comes.
wait_handshake() {
    local stamp
    for _ in $(seq 1 10); do
        stamp=$(as_root wg show "$IFACE" latest-handshakes 2>/dev/null | awk 'NR == 1 { print $2 }')
        [ -n "$stamp" ] && [ "$stamp" != 0 ] && return 0
        sleep 1
    done
    return 1
}

# The menu. fzf, like the other pickers of this shell (fcheat, fnew), and the
# whole list on screen: three servers do not need a scrolling window.
# It needs a terminal, and says which way round that is: a menu cannot be
# answered from a pipe or a script, and a server can be named instead.
pick() {
    local list choice
    list=$(ids)
    [ -n "$list" ] || die "no server in $SERVERS yet - gmake vpn_edit_profiles opens it."
    if ! choice=$(printf '%s\n' "$list" | fzf --prompt="$1 > " --info=inline --layout=reverse); then
        die "no server chosen - a menu needs a terminal. Name one instead: gmake <target> VPN_PROFILE=<id>"
    fi
    [ -n "$choice" ] || die "no server chosen."
    printf '%s\n' "$choice"
}

# The generated profile - the whole point of the two files above: it is not read,
# edited or handed to wg-quick by anyone, it is what servers.json and the two
# variables say, written out just before the tunnel is raised. Every path that
# wants a tunnel goes through here, the boot hook included. A correction made in
# this file by hand is a correction to *this* function, and the next mount would
# take it away again.
compose() {
    local id=$1 private address pub endpoint allowed dns mtu keepalive pair name value

    [ -n "$id" ] || die "no server named: gmake vpn_server picks the default, gmake vpn_up_from_list shows the menu."
    if ! valid_id "$id"; then
        die "'$id' cannot be a server id: letters, digits, dot, dash and underscore only."
    fi
    [ -f "$SERVERS" ] || die "no $SERVERS yet - gmake vpn_edit_profiles creates it from the sample."
    if ! json_ok; then
        die "$SERVERS is not valid JSON: $(jq . "$SERVERS" 2>&1 | head -n 1)"
    fi
    case "$(entries "$id")" in
    1) ;;
    0) die "no server '$id' in $SERVERS. It holds: $(ids | paste -sd' ' -). gmake vpn_edit_profiles opens it." ;;
    *) die "'$id' appears more than once in $SERVERS - one entry per server. gmake vpn_edit_profiles opens it." ;;
    esac

    private=$(field "$id" private_key)
    address=$(field "$id" address)
    pub=$(peer_field "$id" public_key)
    endpoint=$(peer_field "$id" endpoint)
    allowed=$(peer_field "$id" allowed_ips)
    dns=$(field "$id" dns)
    mtu=$(field "$id" mtu)
    keepalive=$(peer_field "$id" persistent_keepalive)
    dns=${dns:-$DNS_DEFAULT}
    mtu=${mtu:-$MTU_DEFAULT}

    # What a profile cannot do without - and the sample's placeholders are not
    # values. A half-filled entry would fail with wg-quick's own words ("Key is
    # not the correct length"), which say nothing about this file: so it is said
    # here, before anything is written.
    for pair in "private_key=$private" "address=$address" "peer.public_key=$pub" \
        "peer.endpoint=$endpoint" "peer.allowed_ips=$allowed"; do
        name=${pair%%=*}
        value=${pair#*=}
        if [ -z "$value" ] || [ "${value#PASTE-}" != "$value" ]; then
            die "server '$id': $name is missing in $SERVERS. gmake vpn_edit_profiles fills it in."
        fi
    done

    # Written as root, mode 600: it carries the private key. The mode is set on
    # the empty file before anything is written into it - `install` truncates an
    # existing file without changing its mode, tee would take the umask - and the
    # content follows on stdin, so no copy of the key lands anywhere else.
    as_root install -d -m 0700 "$WG_DIR"
    as_root install -m 600 /dev/null "$CONF"
    {
        printf '# Generated by the web pack from %s\n' "$SERVERS"
        printf '# Server: %s - do not edit this file: gmake vpn_up rewrites it.\n' "$id"
        printf '\n[Interface]\n'
        printf 'PrivateKey = %s\n' "$private"
        printf 'Address    = %s\n' "$address"
        printf 'DNS        = %s\n' "$dns"
        printf 'MTU        = %s\n' "$mtu"
        if ks_on; then
            printf 'PostUp     = %s\n' "$KS_UP"
            printf 'PreDown    = %s\n' "$KS_DOWN"
        fi
        printf '\n[Peer]\n'
        printf 'PublicKey  = %s\n' "$pub"
        printf 'AllowedIPs = %s\n' "$allowed"
        printf 'Endpoint   = %s\n' "$endpoint"
        # Only when the entry carries one: it keeps a tunnel alive behind a NAT
        # that would otherwise close the mapping, and it is off unless asked for.
        [ -z "$keepalive" ] || printf 'PersistentKeepalive = %s\n' "$keepalive"
    } | as_root tee "$CONF" > /dev/null
}

# Raising the tunnel, with the server named: the profile is rebuilt first, so
# what comes up is what the JSON and the variables say right now. A tunnel
# already up goes down first - it is the same interface, and wg-quick needs the
# file it came up with to undo its own addresses and routes.
cmd_up() {
    local wanted=${1:-}

    if [ -z "$wanted" ]; then
        if [ ! -f "$GLOBAL_ENV" ]; then
            die "no $GLOBAL_ENV yet - 'gmake env_global_enable' builds it from the samples."
        fi
        wanted=$(server_var)
        [ -n "$wanted" ] || die "VPN_PROFILE is not set in $GLOBAL_ENV - gmake vpn_server picks the server, gmake vpn_up_from_list shows the menu."
    fi

    if is_up; then
        run_quiet as_root wg-quick down "$IFACE" ||
            die "the tunnel was up and would not come down - the lines above are wg-quick's own."
    fi
    compose "$wanted"
    run_quiet as_root wg-quick up "$IFACE" ||
        die "the tunnel did not come up - the lines above are wg-quick's own."
    wait_handshake ||
        printf '⚠️  the server has not answered yet - the exit IP below may take a moment.\n' >&2

    # What it did is one thing, where it stands is another, and the second is
    # what is worth reading: up, with which server, with the kill switch, and
    # through which exit IP.
    cmd_status
}

# The same, with the server picked from the menu.
cmd_up_from_list() {
    local wanted
    wanted=$(pick "VPN server")
    cmd_up "$wanted"
}

# A tunnel takes its resolver with it, and openresolv puts back what was there
# before it - unless the copy it saved went with the last restart (it lives in
# /run, which is memory). What is left then is an instance where nothing
# resolves a name: not a state to hand over, so the base the install wrote comes
# back, and the line says it happened. Called before anything else in vpn_down,
# because a tunnel already down is exactly when the file can be missing.
restore_resolver() {
    if [ -r /etc/resolv.conf ]; then
        return 0
    fi
    printf 'nameserver %s\n' "$DNS_BASE" | as_root tee /etc/resolv.conf > /dev/null
    printf '📝 /etc/resolv.conf was gone - %s is back in it.\n' "$DNS_BASE"
}

cmd_down() {
    restore_resolver
    if ! is_up; then
        printf 'ℹ️  no tunnel is up.\n'
        cmd_status
        return 0
    fi
    run_quiet as_root wg-quick down "$IFACE" ||
        die "the tunnel did not come down - the lines above are wg-quick's own."
    cmd_status
}

# The default: the server the distro starts with. It is VPN_PROFILE, so this
# writes a line of .env.global - and it switches to it right away when a tunnel
# is up, so "the server I chose" and "the server I am on" do not disagree until
# the next start.
cmd_server() {
    local wanted=${1:-}

    if [ -z "$wanted" ]; then
        wanted=$(pick "The server the distro starts with")
    fi
    if ! valid_id "$wanted"; then
        die "'$wanted' cannot be a server id: letters, digits, dot, dash and underscore only."
    fi
    if [ -f "$SERVERS" ] && [ "$(entries "$wanted")" != 1 ]; then
        die "no server '$wanted' in $SERVERS. It holds: $(ids | paste -sd' ' -). gmake vpn_edit_profiles opens it."
    fi

    write_env VPN_PROFILE "$wanted"

    # Named explicitly, and not read back from the variable: the value this
    # process was started with is the one from before the line above.
    if is_up; then
        printf '🔁 Switching to %s now.\n' "$wanted"
        cmd_up "$wanted"
    else
        printf 'ℹ️  It will be used by the next mount, and by the next start of the distro.\n'
    fi
    if ! hook_present; then
        printf 'ℹ️  The automatic start is off - gmake vpn_auto_on turns it on.\n'
    fi
}

# The kill switch, on or off: one line of .env.global, and a remount when a
# tunnel is up, so that the answer is true now and not at the next start.
cmd_kill_switch() {
    local what=${1:-} value wanted

    case "$what" in
    on) value=true ;;
    off) value=false ;;
    *) die "kill_switch takes 'on' or 'off'" ;;
    esac

    # A remount needs a server the JSON still holds, and that is asked *before*
    # the variable is written: a failure here would otherwise leave the variable
    # changed and the tunnel as it was, which reads as "half done" from outside.
    if is_up; then
        wanted=$(server_var)
        [ "$(entries "$wanted")" = 1 ] ||
            die "the tunnel is up, and VPN_PROFILE names '$wanted', which $SERVERS does not hold any more. gmake vpn_server picks one, then try this again."
    fi

    write_env VPN_KILL_SWITCH "$value"

    if is_up; then
        printf '🔁 Remounting the tunnel on %s, so this is true now.\n' "$wanted"
        cmd_up "$wanted"
    else
        printf 'ℹ️  It applies to the next mount.\n'
    fi
}

cmd_edit_profiles() {
    local editor

    if [ ! -f "$SERVERS" ]; then
        install -d -m 0700 "$(dirname "$SERVERS")"
        install -m 600 "$SAMPLE" "$SERVERS"
        printf '📝 %s was created from the package sample - fill in your keys.\n' "$SERVERS"
    fi
    if ! json_ok; then
        die "$SERVERS does not parse, and this will not open a broken file: $(jq . "$SERVERS" 2>&1 | head -n 1)"
    fi

    printf 'ℹ️  One entry per server: the id, the address, the private key, and the peer.\n'
    printf '   Both keys and the address come from your Proton account:\n'
    printf '   Downloads, "WireGuard configuration".\n'

    # The editor is yours: $EDITOR when it is set (one command, no arguments),
    # nano otherwise - nano is in the image, and it is what the cheatsheets use.
    editor=${EDITOR:-nano}
    "$editor" "$SERVERS"

    # What the editor left behind. jq says where and why when it does not parse;
    # the ids are checked too, since they are what a menu shows and what
    # .env.global carries. Nothing is read from the file until both hold.
    if ! json_ok; then
        printf '⚠️  %s does not parse any more: %s\n' "$SERVERS" "$(jq . "$SERVERS" 2>&1 | head -n 1)" >&2
        printf '   gmake vpn_edit_profiles opens it again - nothing is read from it until it does.\n' >&2
        return 1
    fi
    check_ids || return 1
    printf '✅ %s: %s\n' "$SERVERS" "$(ids | paste -sd' ' -)"
}

# The automatic start: one line under [boot] in /etc/wsl.conf, which is WSL's own
# hook (the page says why not a systemd unit). Which server no longer belongs to
# this: it is VPN_PROFILE, and the hook reads it from the same .env.global this
# script does.
hook_present() {
    as_root grep -qxF "$HOOK" "$WSLCONF" 2>/dev/null
}

# Both are written idempotently: turning the automatic start on twice leaves one
# line and one copy of the boot script. The line goes under [boot] and nowhere
# else - /etc/wsl.conf is also where the install wrote generateResolvConf, and
# rewriting the file whole would take that with it.
hook_on() {
    as_root install -m 0755 "$here/vpn-boot.sh" "$BOOT_SCRIPT"
    if hook_present; then
        return 0
    fi
    if as_root grep -q '^\[boot\]' "$WSLCONF" 2>/dev/null; then
        as_root sed -i "\|^\[boot\]|a $HOOK" "$WSLCONF"
    else
        printf '\n[boot]\n%s\n' "$HOOK" | as_root tee -a "$WSLCONF" > /dev/null
    fi
    hook_present || die "the [boot] line could not be written to $WSLCONF"
}

hook_off() {
    if as_root test -f "$WSLCONF"; then
        as_root sed -i "\|^${HOOK}$|d" "$WSLCONF"
    fi
    as_root rm -f "$BOOT_SCRIPT"
}

cmd_auto() {
    case "${1:-}" in
    on)
        if [ ! -f "$GLOBAL_ENV" ]; then
            die "no $GLOBAL_ENV yet - 'gmake env_global_enable' builds it from the samples."
        fi
        [ -n "$(server_var)" ] ||
            die "VPN_PROFILE is not set in $GLOBAL_ENV - gmake vpn_server picks the server first."
        hook_on
        printf '✅ The tunnel will come up with the distro, server %s.\n' "$(server_var)"
        printf '   Nothing happens now: it is the next start of the distro that runs it.\n'
        ;;
    off)
        hook_off
        printf '✅ The distro will not bring the tunnel up.\n'
        printf '   A tunnel that is up right now stays up - gmake vpn_down takes it down.\n'
        ;;
    *)
        die "auto takes 'on' or 'off'"
        ;;
    esac
}

cmd_status() {
    local id count in_use ns exit_ip last

    if is_up; then
        printf '🔒 Tunnel      : up (%s)\n' "$IFACE"
    else
        printf '⚪ Tunnel      : down\n'
    fi

    id=$(server_var)
    count=$(ids | wc -l)
    in_use=$(server_in_use)
    if [ ! -f "$SERVERS" ]; then
        printf '   Servers     : none (no %s - gmake vpn_edit_profiles creates it)\n' "$SERVERS"
    elif [ "$count" = 0 ]; then
        printf '   Servers     : none in %s - gmake vpn_edit_profiles opens it\n' "$SERVERS"
    else
        printf '   Servers     : %s in %s\n' "$count" "$SERVERS"
        if [ -n "$in_use" ] && [ "$in_use" != "$id" ] && [ -n "$id" ]; then
            # The two can differ: `gmake vpn_up VPN_PROFILE=ch` connects once
            # without changing the default, and the next mount would use another
            # server - so both are named, and which is which.
            printf '   Server      : %s - up now; VPN_PROFILE names %s\n' "$in_use" "$id"
        elif [ -n "$in_use" ]; then
            printf '   Server      : %s - up now, and what the next mount uses\n' "$in_use"
        elif [ -n "$id" ]; then
            printf '   Server      : %s (VPN_PROFILE)\n' "$id"
        else
            printf '   Server      : none named - gmake vpn_server picks one\n'
        fi
    fi

    printf '   Kill switch : %s\n' "$(ks_line)"

    # openresolv writes this file when the tunnel comes up and puts back what was
    # there when it goes down (measured) - so a missing one is not a state this
    # pack creates, and it is worth saying rather than falling over: without it,
    # nothing on the instance resolves a name. The old version of this line let
    # sed fail and took the whole target down with it.
    if [ -r /etc/resolv.conf ]; then
        ns=$(sed -n 's/^nameserver[[:space:]]\+//p' /etc/resolv.conf 2>/dev/null | head -n 1 || true)
        printf '   DNS         : %s\n' "${ns:-none in /etc/resolv.conf}"
    else
        printf '   DNS         : no /etc/resolv.conf - nothing resolves a name\n'
    fi

    exit_ip=$(curl -s --max-time 8 https://am.i.mullvad.net/ip 2>/dev/null || true)
    printf '   Exit IP     : %s\n' "${exit_ip:-unreachable}"

    if hook_present; then
        printf '   Starts with : the distro\n'
    else
        printf '   Starts with : nothing (gmake vpn_auto_on turns it on)\n'
    fi

    last=$(as_root tail -n 1 "$BOOT_LOG" 2>/dev/null || true)
    [ -n "$last" ] && printf '   Last start  : %s\n' "$last"
    return 0
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
up_from_list)
    shift
    cmd_up_from_list "$@"
    ;;
down)
    shift
    cmd_down "$@"
    ;;
server)
    shift
    cmd_server "$@"
    ;;
kill_switch)
    shift
    cmd_kill_switch "$@"
    ;;
edit_profiles)
    shift
    cmd_edit_profiles "$@"
    ;;
auto)
    shift
    cmd_auto "$@"
    ;;
*)
    cat <<'USAGE'
usage: vpn.sh <command>

  status                the tunnel, the server, the kill switch, the DNS, the
                        exit IP, and what the distro starts with
  up [id]               connect now, with the server VPN_PROFILE names
  up_from_list          connect now, picking the server from the JSON in a menu
  down                  disconnect
  server [id]           the server the distro starts with - the menu picks one
                        when no id is named (gmake vpn_server VPN_PROFILE=<id>)
  kill_switch on|off    the kill switch in the tunnel, and a remount
  auto on|off           bring the tunnel up with the distro
  edit_profiles         open ~/.config/vpn/servers.json in the editor

Every command is a gmake target of the same name: gmake vpn_status, vpn_up,
vpn_up_from_list, vpn_down, vpn_server, vpn_ks_on, vpn_ks_off, vpn_auto_on,
vpn_auto_off, vpn_edit_profiles.
USAGE
    exit 2
    ;;
esac
