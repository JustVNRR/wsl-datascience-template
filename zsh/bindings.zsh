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

# Alt + Shift + C: Open the Zsh configuration directory in VS Code
_open_zsh_conf() {
    code "$ZDOTDIR"
    zle reset-prompt
}
zle -N _open_zsh_conf
bindkey '^[C' _open_zsh_conf

# Alt + r: Open the persistent history file in VS Code (XDG compliant)
_open_hist_file() {
    code "$HISTFILE"
    zle reset-prompt
}
zle -N _open_hist_file
bindkey '^[r' _open_hist_file

# --- 2. PROMPT BUFFER INSERTION ---

# Ctrl + F: Insert the path of a VISIBLE file at the current cursor position
_fzf_file_no_hidden() {
    local result
    result=$(fdfind --type f --exclude '.*' | fzf --preview "$_FZF_PREVIEW_CMD")
    if [[ -n "$result" ]]; then
        LBUFFER+="$result"
    fi
    zle reset-prompt
}
zle -N _fzf_file_no_hidden
bindkey '^F' _fzf_file_no_hidden

# Ctrl + G: Insert an alias at the current cursor position
zle -N _falias_widget
bindkey '^G' _falias_widget

# Ctrl + H: Load a cheatsheet command directly into the prompt buffer
zle -N _fcheat_widget
bindkey '^H' _fcheat_widget