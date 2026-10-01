#!/bin/sh
# ==============================================================================
# THE MESSAGES
# ==============================================================================
# A message says what kind of line it is; the colour is decided once, here,
# over the names in lib/colours.sh. The kinds are the Windows side's, in
# scripts/message.ps1: error, warning, success, info, muted, hint.
#
# Never read by the interactive shell: these six names would land in a session
# and shadow what it means by them. A script reads it with:
#   . "${ZDOTDIR:-$HOME/.config/zsh}/lib/message.sh"
#
# warning and hint share the yellow: a fixed palette has one colour that reads
# anywhere, and the two names keep the intent apart until they need to differ.
# shellcheck source=/dev/null
. "${ZDOTDIR:-$HOME/.config/zsh}/lib/colours.sh"
error()   { printf '%s%s%s\n' "$C_RED" "$*" "$C_RESET"; }
warning() { printf '%s%s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
success() { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
info()    { printf '%s%s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
muted()   { printf '%s%s%s\n' "$C_GREY" "$*" "$C_RESET"; }
hint()    { printf '%s%s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
