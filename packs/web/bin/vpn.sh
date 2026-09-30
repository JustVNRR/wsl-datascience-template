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
#   ~/.config/vpn/servers.json    your servers: one entry per server, with
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
# over openresolv for the DNS, the kill switch as two iptables lines (scoped to
# this instance), and WSL's own boot hook for the automatic start (not a systemd
# unit - see vpn-boot.sh).

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


# The kill switch: two iptables lines, in the generated profile, that reject
# whatever would leave outside the tunnel. The mark is the one wg-quick puts on
# its own packets, and LOCAL destinations (loopback, WSLg, the Docker socket) are
# spared - without that last part, the terminal this was typed in would go quiet
# first. The $( ) below belongs to wg-quick: it is expanded when the tunnel comes
# up, not here.
#
# And the lines name this instance, not the machine. Every distro of a WSL box
# shares one kernel and one firewall, so a plain rule blocks every neighbour's
# traffic too - and only the instance that wrote a rule can take it back out.
# WSL gives each distro its own place in the shared cgroup tree
# (/wsl-user/distro-NNNN, measured), iptables can match on that place, and a
# comment makes the rules findable from anywhere: that is what -m cgroup
# --path and -m comment --comment are doing below, and what the sweep in
# vpn_ks_off, vpn_down and vpn_up reads.
KS_COMMENT='wsl-stack kill switch'

# This instance's place in the cgroup tree. A session opened from Windows is
# already in it; the boot hook is not (a child of the distro's init sits at
# the cgroup root), so it borrows the place of any session that is open - and
# the distro was started by one. Empty when WSL says nothing usable: the kill
# switch then stays out of the kernel and says so, because a rule without a
# place is exactly the machine-wide rule all of this exists to remove.
# CGROUP_ROOT is what the tests point at a stand-in tree.
CGROUP_ROOT=${CGROUP_ROOT:-/proc}
cgroup_distro_path() {
    local p=
    p=$(sed -n 's/^[0-9]*::\(\/wsl-user\/distro-[^[:space:]]*\)$/\1/p' "$CGROUP_ROOT/self/cgroup" 2>/dev/null | head -n 1 || true)
    if [ -z "$p" ]; then
        p=$(sed -n 's/^[0-9]*::\(\/wsl-user\/distro-[^[:space:]]*\)$/\1/p' "$CGROUP_ROOT"/[0-9]*/cgroup 2>/dev/null | head -n 1 || true)
    fi
    printf '%s\n' "$p"
}

# One hook line, both address families, for one verb: what wg-quick runs to
# lay the rules (PostUp) and to take them back out (PreDown). Both are built
# from the same words here, because a -D that differs from its -I by one match
# deletes nothing - and says nothing. The tail is where the verbs differ by
# nature: raising the tunnel fails loudly if a rule cannot be laid, while
# tearing it down only tries - what it misses, the sweep finds by label.
ks_rule() { # $1: -I or -D, $2: this instance's cgroup path, $3: the verb's tail
    # shellcheck disable=SC2016
    printf 'iptables %s OUTPUT ! -o %%i -m cgroup --path "%s" -m mark ! --mark $(wg show %%i fwmark) -m addrtype ! --dst-type LOCAL -m comment --comment "%s" -j REJECT%s; ip6tables %s OUTPUT ! -o %%i -m cgroup --path "%s" -m mark ! --mark $(wg show %%i fwmark) -m addrtype ! --dst-type LOCAL -m comment --comment "%s" -j REJECT%s' \
        "$1" "$2" "$KS_COMMENT" "$3" "$1" "$2" "$KS_COMMENT" "$3"
}

die() {
    printf '%s\n' "$*" >&2
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

# Every kill-switch rule still in the kernel goes - whichever instance wrote
# it, whatever its cgroup path says - and nothing else does. The label is what
# makes this possible from anywhere: the rules are found by reading the chains
# (list with numbers, cut the first line carrying the comment, repeat), never
# by rebuilding a spec - the fwmark in it is gone with the interface - and
# never by flushing the chain, where Docker's own rules live. Answers how many
# went.
ks_sweep() {
    local fam='' num='' removed=0
    for fam in iptables ip6tables; do
        while :; do
            num=$(as_root "$fam" -L OUTPUT --line-numbers -n 2>/dev/null | grep -m 1 -F -- "$KS_COMMENT" | awk '{print $1}')
            [ -n "$num" ] || break
            as_root "$fam" -D OUTPUT "$num" 2>/dev/null || break
            removed=$((removed + 1))
        done
    done
    printf '%s' "$removed"
}

# One word for the sweep's answer, said the same way wherever it lands.
ks_swept_message() {
    local word=rules
    if [ "$1" -eq 1 ]; then
        word=rule
    fi
    printf 'Removed %s kill-switch %s still in the kernel.\n' "$1" "$word"
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
            printf 'id "%s" is not usable: letters, digits, dot, dash and underscore only.\n' "$id" >&2
            printf '   It is shown in the menus and written into .env.global, where a space or a # would not survive.\n' >&2
            return 1
        fi
        case " $seen " in
        *" $id "*)
            printf 'id "%s" appears twice - one entry per server.\n' "$id" >&2
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

# What the kill switch is, in one line, for vpn_status and for the message a
# mount ends with: the variable says what was asked, the kernel says what is -
# and the two can disagree (a tunnel mounted elsewhere carries the rules, a
# crash left them behind, this mount has none yet). The rules carry the label,
# so the kernel's answer is countable, and this instance's place separates
# "here" from "a neighbour".
ks_line() {
    local state rules total here path word
    if [ ! -r "$GLOBAL_ENV" ]; then
        printf 'off (no %s yet - gmake env_global_enable builds it)\n' "$GLOBAL_ENV"
        return 0
    fi
    if ks_on; then
        state=on
    else
        state="off ($(env_var VPN_KILL_SWITCH))"
    fi

    rules=$(as_root sh -c 'iptables -S OUTPUT 2>/dev/null; ip6tables -S OUTPUT 2>/dev/null' | grep -F -- "$KS_COMMENT" || true)
    total=$(printf '%s\n' "$rules" | grep -c . || true)
    path=$(cgroup_distro_path)
    here=0
    if [ -n "$path" ]; then
        here=$(printf '%s\n' "$rules" | grep -c -F -- "--path \"$path\"" || true)
    fi

    if [ "$total" -eq 0 ]; then
        printf '%s - no rule in the kernel\n' "$state"
    elif [ "$here" -gt 0 ]; then
        word=rules
        if [ "$here" -eq 1 ]; then
            word=rule
        fi
        printf '%s - %s %s in the kernel, this instance\n' "$state" "$here" "$word"
    else
        word=rules
        if [ "$total" -eq 1 ]; then
            word=rule
        fi
        printf '%s - %s %s in the kernel, another instance\n' "$state" "$total" "$word"
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
    printf '\nWrote %s=%s (%s)\n' "$name" "$value" "$GLOBAL_ENV"
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
    local id=$1 private address pub endpoint allowed dns mtu keepalive pair name value ks_path

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
    dns=$(field "$id" DNS)
    mtu=$(field "$id" mtu)
    keepalive=$(peer_field "$id" persistent_keepalive)
    [ -n "$mtu" ] || mtu=$(env_var VPN_MTU)
    [ -n "$mtu" ] || die "VPN_MTU is not set in $GLOBAL_ENV - gmake env_global_enable writes it from the sample."
    # What a profile cannot do without - and the sample's placeholders are not
    # values. A half-filled entry would fail with wg-quick's own words ("Key is
    # not the correct length"), which say nothing about this file: so it is said
    # here, before anything is written.
    for pair in "DNS=$dns" "private_key=$private" "address=$address" "peer.public_key=$pub" \
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
            ks_path=$(cgroup_distro_path)
            if [ -n "$ks_path" ]; then
                printf 'PostUp     = %s\n' "$(ks_rule -I "$ks_path" '')"
                printf 'PreDown    = %s\n' "$(ks_rule -D "$ks_path" ' || true')"
            else
                printf 'the kill switch is on, but this instance has no /wsl-user/distro-* place of its own: no rule was added - a machine-wide rule is exactly what this must never lay.\n' >&2
            fi
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

# The base resolver, written the way vpn.md's recipe writes it by hand, before
# every mount: openresolv hands back what it found before it took the file over,
# so what it found is what the instance resolves with once the tunnel is down.
# Done here as well as at install because an instance built from the image never
# ran that install on a real filesystem - see install.sh.
write_base_resolver() {
    local base
    base=$(env_var BASE_DNS)
    [ -n "$base" ] || die "BASE_DNS is not set in $GLOBAL_ENV - gmake env_global_enable writes it from the sample."
    as_root ln -sf /run/resolvconf/resolv.conf /etc/resolv.conf 2>/dev/null || true
    printf 'nameserver %s\n' "$base" | as_root resolvconf -a wsl.base
}

# Raising the tunnel, with the server named: the profile is rebuilt first, so
# what comes up is what the JSON and the variables say right now. A tunnel
# already up goes down first - it is the same interface, and wg-quick needs the
# file it came up with to undo its own addresses and routes.
cmd_up() {
    local swept

    if ip link show dev "$IFACE" >/dev/null 2>&1 && [ ! -f "$CONF" ]; then
        as_root ip link delete dev "$IFACE" 2>/dev/null || true
    fi

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
    # Before anything is raised: a leftover from a mount that died carries the
    # label and an older fwmark, and it would reject the very tunnel about to
    # come up. The sweep is what makes "up" mean "the rules in place are the
    # ones this mount wrote".
    swept=$(ks_sweep)
    if [ "$swept" -gt 0 ]; then
        ks_swept_message "$swept"
    fi
    write_base_resolver
    compose "$wanted"
    run_quiet as_root wg-quick up "$IFACE" ||
        die "the tunnel did not come up - the lines above are wg-quick's own."
    wait_handshake ||
        printf 'the server has not answered yet - the exit IP below may take a moment.\n' >&2

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

cmd_down() {
    local swept
    if ! is_up; then
        printf 'no tunnel is up.\n'
        swept=$(ks_sweep)
        if [ "$swept" -gt 0 ]; then
            ks_swept_message "$swept"
        fi
        if [ ! -e /etc/resolv.conf ]; then
            write_base_resolver
        fi
        cmd_status
        return 0
    fi

    if [ ! -f "$CONF" ]; then
        printf '%s missing, tearing down kernel interface and removing the kill-switch rules directly.\n' "$CONF"
        as_root ip link delete dev "$IFACE" 2>/dev/null || true
        swept=$(ks_sweep)
        if [ "$swept" -gt 0 ]; then
            ks_swept_message "$swept"
        fi
        as_root resolvconf -d "$IFACE" 2>/dev/null || true
        write_base_resolver
        cmd_status
        return 0
    fi

    run_quiet as_root wg-quick down "$IFACE" ||
        die "the tunnel did not come down - the lines above are wg-quick's own."
    # The PreDown took this mount's rules with it; a rule from anywhere else -
    # another instance, a mount that died before it tore down - carries the
    # same label, and "down" is when a user means all of them.
    swept=$(ks_sweep)
    if [ "$swept" -gt 0 ]; then
        ks_swept_message "$swept"
    fi
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
        die "no server '$wanted' in $SERVERS. It holds: $(ids | paste -sd' ' -). Run gmake vpn_edit_profiles to open it."
    fi

    write_env VPN_PROFILE "$wanted"

    # Named explicitly, and not read back from the variable: the value this
    # process was started with is the one from before the line above.
    if is_up; then
        printf 'Switching to %s now.\n' "$wanted"
        cmd_up "$wanted"
    else
        printf 'Run gmake vpn_up or restart your distro to use this profile.\n'
    fi
    if ! hook_present; then
        printf 'Run gmake vpn_auto_on to turn on automatic vpn activation.\n'
    fi
}

# The kill switch, on or off: one line of .env.global, and a remount when a
# tunnel is up, so that the answer is true now and not at the next start.
cmd_kill_switch() {
    local what=${1:-} value wanted swept

    case "$what" in
    on) value=true ;;
    off) value=false ;;
    *) die "kill_switch takes 'on' or 'off'" ;;
    esac

    # A remount needs a server the JSON still holds, and that is asked *before*
    # the variable is written: a failure here would otherwise leave the variable
    # changed and the tunnel as it was, which reads as "half done" from outside.
    # Only a tunnel this instance can remount - interface up, profile here - is
    # remounted at all: an interface a neighbour raised comes with no profile
    # of ours to read, and tearing it down would take their tunnel with it.
    if is_up && [ -f "$CONF" ]; then
        wanted=$(server_var)
        [ "$(entries "$wanted")" = 1 ] ||
            die "the tunnel is up, and VPN_PROFILE names '$wanted', which $SERVERS does not hold any more. gmake vpn_server picks one, then try this again."
    fi

    write_env VPN_KILL_SWITCH "$value"

    if [ "$value" = false ]; then
        # Off means off, wherever the rules are: the remount takes back this
        # mount's (its PreDown), and the sweep takes back everything else the
        # label finds - a leftover from an instance that stopped mid-flight, a
        # rule from before a rebuild - from here, no tunnel required.
        if is_up && [ -f "$CONF" ]; then
            printf 'Remounting the tunnel on %s, so this is true now.\n' "$wanted"
            cmd_up "$wanted"
        fi
        swept=$(ks_sweep)
        if [ "$swept" -gt 0 ]; then
            ks_swept_message "$swept"
        elif ! is_up || [ ! -f "$CONF" ]; then
            printf 'It applies to the next mount.\n'
        fi
    elif is_up && [ -f "$CONF" ]; then
        printf 'Remounting the tunnel on %s, so this is true now.\n' "$wanted"
        cmd_up "$wanted"
    else
        printf 'It applies to the next mount.\n'
    fi
}

cmd_edit_profiles() {
    local editor

    if [ ! -f "$SERVERS" ]; then
        install -d -m 0700 "$(dirname "$SERVERS")"
        install -m 600 "$SAMPLE" "$SERVERS"
        printf '%s was created from the package sample - fill in your keys.\n' "$SERVERS"
    fi
    if ! json_ok; then
        die "$SERVERS does not parse, and this will not open a broken file: $(jq . "$SERVERS" 2>&1 | head -n 1)"
    fi

    # The editor is yours: $EDITOR when it is set (one command, no arguments),
    # nano otherwise - nano is in the image, and it is what the cheatsheets use.
    editor=${EDITOR:-nano}
    eval "$editor \"\$SERVERS\""

    # What the editor left behind. jq says where and why when it does not parse;
    # the ids are checked too, since they are what a menu shows and what
    # .env.global carries. Nothing is read from the file until both hold.
    if ! json_ok; then
        printf '%s does not parse any more: %s\n' "$SERVERS" "$(jq . "$SERVERS" 2>&1 | head -n 1)" >&2
        printf '   gmake vpn_edit_profiles opens it again - nothing is read from it until it does.\n' >&2
        return 1
    fi
    check_ids || return 1
    printf '%s: %s\n' "$SERVERS" "$(ids | paste -sd' ' -)"

    # And now the server to use, straight away: the menu is the list the file
    # holds, so a name that no longer exists cannot stay in VPN_PROFILE, and what
    # the file contains is what the user is asked to choose from.
    #
    # Only with a terminal: a test or a script runs this with EDITOR=true, and a
    # menu has nothing to ask with there - the edit stands on its own.
    if [ -t 0 ] && [ -t 1 ]; then
        cmd_server
    fi
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
        printf 'The tunnel will come up with the distro, server %s.\n' "$(server_var)"
        printf '   Nothing happens now: it is the next start of the distro that runs it.\n'
        ;;
    off)
        hook_off
        printf 'The distro will not bring the tunnel up.\n'
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
        printf '   Tunnel      : up (%s)\n' "$IFACE"
    else
        printf '   Tunnel      : down\n'
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

    exit_ip=$(curl -s --max-time 8 https://api.ipify.org 2>/dev/null || true)
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
  kill_switch on|off    the kill switch in the tunnel (this instance only),
                        and a remount - off also sweeps rules left behind
  auto on|off           bring the tunnel up with the distro
  edit_profiles         open ~/.config/vpn/servers.json in the editor

Every command is a gmake target of the same name: gmake vpn_status, vpn_up,
vpn_up_from_list, vpn_down, vpn_server, vpn_ks_on, vpn_ks_off, vpn_auto_on,
vpn_auto_off, vpn_edit_profiles.
USAGE
    exit 2
    ;;
esac
