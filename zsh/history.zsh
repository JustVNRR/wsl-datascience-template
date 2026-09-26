# ============================================================
# HISTORY CONFIGURATION
# ============================================================

# 1. Storage path and limits
HISTFILE="$HOME/.local/state/zsh/history"
HISTSIZE=100000
SAVEHIST=100000

# 2. Multi-terminal session sharing
setopt APPEND_HISTORY
setopt SHARE_HISTORY

# 3. Deduplication management
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

# 4. Security (commands prefixed with leading space bypass history)
setopt HIST_IGNORE_SPACE

# 5. What is not worth remembering
# A command that does not exist never ran: a slip of the fingers, and the shell
# answered `command not found`. zsh has no option for this, but it has a hook -
# `zshaddhistory` sees the line BEFORE it runs, and returning 1 keeps it out of
# the history. Only the first word is looked at, and its existence is asked of
# zsh, so an alias, a function, a builtin and a keyword (`for`, `if`) all count,
# and a whole `for` loop is kept as one entry.
# Two lines are kept whatever they open on, because their first word is not the
# command: `FOO=bar cmd`, which opens on an assignment, and `$EDITOR file`,
# whose name is in the variable. Losing either would cost real work, and the
# filter is not worth a false accusation.
# HIST_IGNORE_SPACE above is still the way to leave a line out on purpose: start
# it with a space.
zshaddhistory() {
    local -a words
    words=(${(z)1})

    [[ -n "$words[1]" ]] || return 0
    [[ "$words[1]" == *=* ]] && return 0
    [[ "$words[1]" == *'$'* ]] && return 0

    whence -w -- "$words[1]" >/dev/null 2>&1 && return 0
    return 1
}
