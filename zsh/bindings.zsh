# ============================================================
# ZLE KEYBINDINGS (KEYBOARD SHORTCUTS)
# ============================================================

# --- 1. OPEN IN VS CODE ---

# Alt + o: Fuzzy-find and open a VISIBLE file in VS Code
_fv_widget() {
    zle -I
    fv
    zle reset-prompt
}
zle -N _fv_widget
bindkey '^[o' _fv_widget

# Alt + a: Fuzzy-find and open ANY file (including hidden) in VS Code
_fa_widget() {
    zle -I
    fa
    zle reset-prompt
}
zle -N _fa_widget
bindkey '^[a' _fa_widget

# Ctrl + X then v: Open the Zsh configuration directory in VS Code. `v` for VS
# Code, and the slot was free: zsh binds neither ^Xv nor ^XV.
_open_zsh_conf() {
    code "$ZDOTDIR"
    zle reset-prompt
}
zle -N _open_zsh_conf
bindkey '^Xv' _open_zsh_conf

# Alt + r: Open the persistent history file in VS Code (XDG compliant)
_open_hist_file() {
    code "$HISTFILE"
    zle reset-prompt
}
zle -N _open_hist_file
bindkey '^[r' _open_hist_file

# --- 2. PROMPT BUFFER INSERTION ---

# Ctrl + X then g: Insert the path of a VISIBLE file at the current cursor
# position. zsh bound ^Xg AND ^XG to list-expand - the same widget twice - so
# one of the two was there for the taking, and ^Xg is the one without Shift.
_fzf_file_no_hidden() {
    local result
    result=$(fdfind --type f --exclude '.*' | fzf --preview "$_FZF_PREVIEW_CMD")
    if [[ -n "$result" ]]; then
        LBUFFER+="$result"
    fi
    zle reset-prompt
}
zle -N _fzf_file_no_hidden
bindkey '^Xg' _fzf_file_no_hidden

# Alt + y: Insert an alias at the current cursor position. ^[y was yank-pop,
# which only does anything right after a Ctrl+Y.
zle -N _falias_widget
bindkey '^[y' _falias_widget

# Alt + z: Load a cheatsheet command directly into the prompt buffer. ^[z
# relaunched the last named command, a zsh feature almost nobody uses.
zle -N _fcheat_widget
bindkey '^[z' _fcheat_widget