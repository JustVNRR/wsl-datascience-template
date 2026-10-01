#!/usr/bin/env bash
# ==============================================================================
# THE SHELL COLOURS
# ==============================================================================
# The only shell file that writes an escape sequence. A colour is written once,
# here, and the files that display colour read a name: zsh/aliases.zsh,
# zsh/cheatsheet.zsh and the packs' pickers take the variables, and the scripts
# take them through lib/message.sh, which maps a message's kind to one of them.
#
# The make side has its twin, gmake/make/colours.mk. Make expands text and
# cannot read a shell file, so the codes the modules need are spelled there as
# well - a colour changed in one file is changed in the other.
#
# The codes are the ones the template already displayed; the claude status line
# keeps its own, brighter palette. The bash shebang describes the two readers -
# the scripts' bash and the interactive zsh - not a script: both read the
# $'...' quoting.
#
# Nothing else belongs in this file: .zshrc reads it into a running session,
# where a `set` would land in that session's options.
export C_RESET=$'\033[0m'
export C_RED=$'\033[31m'
export C_GREEN=$'\033[32m'
export C_YELLOW=$'\033[33m'
export C_CYAN=$'\033[36m'
export C_GREY=$'\033[90m'
