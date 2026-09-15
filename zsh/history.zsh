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
