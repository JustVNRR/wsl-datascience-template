# ============================================================
# 1. OH MY ZSH DEFAULT ALIAS CLEANUP
# ============================================================

unalias rm 2>/dev/null
unalias lt 2>/dev/null

# ============================================================
# 2. CUSTOM SHORTCUTS & SYSTEM UTILITIES
# ============================================================

# Target the global Makefile inside $ZDOTDIR cheatsheet directory
alias gmake="make -f $ZDOTDIR/cheatsheets/global_makefile.mk"

# Directory navigation & open network ports
alias b='cd -'
alias ports='sudo lsof -i -P -n | grep LISTEN'

# Quick configuration edits and reload (XDG compliant)
alias zsh_conf='code ~/.config/zsh'
alias reload='source ~/.config/zsh/.zshrc'

# ============================================================
# 3. MODERN UTILITIES (RUST STACK)
# ============================================================

# eza (ls replacement with icons and Git status integration)
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias ll='eza -lh --icons --git'
    alias la='eza -lah --icons --git'
    alias tree='eza --tree --icons'
fi

# bat (cat replacement featuring syntax highlighting)
if command -v batcat >/dev/null 2>&1; then
    alias cat='batcat'
fi

# ripgrep (fast grep alternative)
if command -v rg >/dev/null 2>&1; then
    alias grep='rg --color=auto'
fi

# ============================================================
# 4. ALIAS FUZZY PICKER (FALIAS)
# ============================================================

# Interactively fuzzy-select an alias using fzf and return only its identifier
_falias_select() {
    alias |
        awk -F'=' '{
            printf "%-25s \033[90m->\033[0m %s\n", $1, $2
        }' |
        fzf \
            --ansi \
            --prompt="💡 Shortcuts > " \
            --info=inline \
            --layout=reverse |
        awk '{print $1}'
}

# CLI command: falias
falias() {
    local alias_name
    alias_name=$(_falias_select)
    [[ -z "$alias_name" ]] && return
    print -z -- "$alias_name "
}

# ZLE Widget: Ctrl + A
_falias_widget() {
    local alias_name
    alias_name=$(_falias_select)
    [[ -z "$alias_name" ]] && {
        zle redisplay
        return
    }
    LBUFFER+="$alias_name "
    zle redisplay
}