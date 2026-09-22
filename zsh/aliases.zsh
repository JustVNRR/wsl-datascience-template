# ============================================================
# 1. OH MY ZSH DEFAULT ALIAS CLEANUP
# ============================================================

unalias rm 2>/dev/null
unalias lt 2>/dev/null

# ============================================================
# 2. CUSTOM SHORTCUTS & SYSTEM UTILITIES
# ============================================================

# Target the global Makefile inside $ZDOTDIR gmake directory
alias gmake="make -f $ZDOTDIR/gmake/global_makefile.mk"

# Directory navigation & open network ports
alias b='cd -'
alias ports='sudo lsof -i -P -n | grep LISTEN'

# Quick configuration edits and reload (XDG compliant)
alias zsh_conf='code ~/.config/zsh'

# exec, not source: re-reading the configuration inside a LIVE shell makes zsh
# expand the alias table it already holds while it re-parses Oh My Zsh's lib,
# and OMZ defines GLOBAL aliases (P, L, G, H...) that expand anywhere. The `P`
# of `zparseopts -D -E -a opts r m P` then becomes `2>&1 | pygmentize -l pytb`,
# which breaks omz_urlencode at every single prompt. A fresh process reads the
# configuration in the normal order - lib before plugins - and cannot hit that.
# It also avoids double-registering the hooks the plugins install.
alias reload='exec zsh'

# ============================================================
# 3. MODERN UTILITIES (RUST STACK)
# ============================================================

# eza (ls replacement with icons and Git status integration)
# --icons=always, never a bare --icons: the flag takes an optional value
# (always|auto|never), so a bare one swallows whatever follows it - `ls /tmp`
# died on "invalid value '/tmp' for '--icons'". `auto` renders no icon here
# even on a terminal, so `always` is what the flag meant before it took a value.
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons=always'
    alias ll='eza -lh --icons=always --git'
    alias la='eza -lah --icons=always --git'
    alias tree='eza --tree --icons=always'
fi

# bat (cat replacement featuring syntax highlighting)
if command -v batcat >/dev/null 2>&1; then
    alias cat='batcat'
fi

alias grep='grep --color=auto'

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

# ZLE Widget: Alt + y
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