#!/usr/bin/env bash
# ==============================================================================
# THE OLD PROFILES - INTO THE JSON
# ==============================================================================
# The pack used to keep one WireGuard profile per server in /etc/wireguard, and
# read them there. It reads ~/.config/vpn/servers.json now, and this is what
# carries a machine from the one to the other: the values of each .conf become an
# entry of the JSON, and the .conf files are left where they are - they are the
# user's, and deleting them is their call, not the pack's.
#
# install.sh calls this once, when the JSON does not exist yet, and falls back to
# copying the sample when there is nothing to carry. Nothing is written when the
# JSON is already there: it is what the user edits, and it holds their keys.
#
#   usage: vpn-migrate.sh <path to servers.json>
#
# What is carried: the private key, the address, and the peer (public key,
# endpoint, allowed IPs, and the keepalive when the profile asks for one). The
# DNS and the MTU only when they differ from the ones the generator applies to
# every server (10.2.0.1 and 1420) - a value that is already the default does not
# belong in an entry.
#
# What is not carried, and is reported: the kill switch lines (PostUp/PreDown),
# which are the VPN_KILL_SWITCH variable now, and any other key the JSON has no
# field for - a silent half-migration would be a tunnel that half-works.

set -euo pipefail

WG_DIR=/etc/wireguard
DNS_DEFAULT=10.2.0.1
MTU_DEFAULT=1420

target=${1:-}
if [ -z "$target" ]; then
    echo "usage: vpn-migrate.sh <path to servers.json>" >&2
    exit 2
fi

die() {
    printf '❌ %s\n' "$*" >&2
    exit 1
}

if [ -e "$target" ]; then
    printf 'ℹ️  %s is already there - nothing was migrated.\n' "$target"
    exit 0
fi

# The folder is root-only, so the listing goes through sudo, and the reading
# happens on this side of the pipe. vpn.conf is not a server of the user's: it is
# the file the pack generates, and it has nothing to carry over.
conf_files=$(sudo find "$WG_DIR" -maxdepth 1 -type f -name '*.conf' 2>/dev/null | sort || true)
conf_files=$(printf '%s\n' "$conf_files" | grep -v "/vpn\.conf$" || true)
if [ -z "$conf_files" ]; then
    printf 'ℹ️  no profile to migrate in %s.\n' "$WG_DIR"
    exit 0
fi

# One line per setting, as section<TAB>Key<TAB>value. Sections matter: PrivateKey
# and Address live under [Interface], the peer's keys under [Peer], and two
# profiles can carry the same key name in both.
#
# The split is on the FIRST `=` of the line, and that is not a detail: a base64
# private key ends with one (`...=`, the padding), and splitting on every `=`
# would hand over a key one character short.
parse_conf() {
    awk '
        /^[[:space:]]*\[/ { section = tolower($0); gsub(/[^a-z]/, "", section); next }
        /^[[:space:]]*(#|$)/ { next }
        {
            cut = index($0, "=")
            if (cut == 0 || section == "") { next }
            key = substr($0, 1, cut - 1); gsub(/[[:space:]]/, "", key)
            value = substr($0, cut + 1)
            sub(/^[[:space:]]+/, "", value); sub(/[[:space:]]+$/, "", value)
            if (key != "") { print section "\t" key "\t" value }
        }'
}

# The first value of that setting, empty when the profile has none.
value_of() {
    local section=$1 key=$2 pairs=$3
    printf '%s\n' "$pairs" | awk -F'\t' -v s="$section" -v k="$key" '$1 == s && $2 == k { print $3; exit }'
}

# What the JSON has no field for. The kill switch is not in this list: it is
# carried, as the VPN_KILL_SWITCH variable, and the summary below says so.
unknown_keys() {
    local pairs=$1
    printf '%s\n' "$pairs" | awk -F'\t' '
        BEGIN {
            known["interface\tPrivateKey"] = 1
            known["interface\tAddress"] = 1
            known["interface\tDNS"] = 1
            known["interface\tMTU"] = 1
            known["interface\tPostUp"] = 1
            known["interface\tPreDown"] = 1
            known["peer\tPublicKey"] = 1
            known["peer\tAllowedIPs"] = 1
            known["peer\tEndpoint"] = 1
            known["peer\tPersistentKeepalive"] = 1
        }
        !(($1 "\t" $2) in known) { print "[" toupper(substr($1, 1, 1)) substr($1, 2) "] " $2 }'
}

entries=$(mktemp)
trap 'rm -f "$entries"' EXIT

printf '📝 Reading the profiles of %s into %s...\n' "$WG_DIR" "$target"
count=0
no_kill_switch=
while read -r conf; do
    [ -n "$conf" ] || continue
    id=$(basename "$conf" .conf)
    pairs=$(sudo cat "$conf" | parse_conf)

    key=$(value_of interface PrivateKey "$pairs")
    address=$(value_of interface Address "$pairs")
    pub=$(value_of peer PublicKey "$pairs")
    endpoint=$(value_of peer Endpoint "$pairs")
    allowed=$(value_of peer AllowedIPs "$pairs")
    keepalive=$(value_of peer PersistentKeepalive "$pairs")
    dns=$(value_of interface DNS "$pairs")
    mtu=$(value_of interface MTU "$pairs")
    [ "$dns" = "$DNS_DEFAULT" ] && dns=
    [ "$mtu" = "$MTU_DEFAULT" ] && mtu=
    [ -n "$(value_of interface PostUp "$pairs")" ] || no_kill_switch="$no_kill_switch $id"

    while read -r line; do
        [ -n "$line" ] || continue
        printf '⚠️  %s: %s has no field in the JSON and was not carried over.\n' "$id" "$line"
    done <<< "$(unknown_keys "$pairs")"

    jq -nc --arg id "$id" --arg address "$address" --arg key "$key" \
        --arg pub "$pub" --arg endpoint "$endpoint" --arg allowed "$allowed" \
        --arg keepalive "$keepalive" \
        --arg note "migrated from $conf" --arg dns "$dns" --arg mtu "$mtu" '
        {id: $id, note: $note, address: $address, private_key: $key,
         peer: ({public_key: $pub, endpoint: $endpoint, allowed_ips: $allowed}
                + (if $keepalive == "" then {} else {persistent_keepalive: $keepalive} end))}
        + (if $dns == "" then {} else {dns: $dns} end)
        + (if $mtu == "" then {} else {mtu: $mtu} end)' >> "$entries"
    count=$((count + 1))
done <<< "$conf_files"

[ "$count" -gt 0 ] || die "no profile could be read."

tmp=$(mktemp)
trap 'rm -f "$entries" "$tmp"' EXIT
jq -n --slurpfile servers "$entries" \
    '{note: "One entry per server. gmake vpn_edit_profiles opens this file.", servers: $servers}' > "$tmp"
[ -s "$tmp" ] || die "the JSON could not be written."

install -d -m 0700 "$(dirname "$target")"
install -m 600 "$tmp" "$target"

printf '✅ %s servers are in %s: %s\n' "$count" "$target" "$(jq -r '[.servers[].id] | join(" ")' "$target")"
printf '   The profiles in %s are left where they are - delete them when you want.\n' "$WG_DIR"
if [ -n "$no_kill_switch" ]; then
    printf 'ℹ️  No kill switch in:%s. It is the VPN_KILL_SWITCH variable now - gmake vpn_ks_off if you want none.\n' "$no_kill_switch"
fi
