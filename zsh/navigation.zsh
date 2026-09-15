# ============================================================
# NAVIGATION & DIRECTORY BEHAVIOR
# ============================================================

# 1. Zsh Comfort Options
setopt AUTOCD            # Type directory path directly to cd into it
setopt NOBEEP            # Mute terminal audio completely (no error beeps)
setopt NUMERIC_GLOB_SORT # Sort files with natural numeric ordering (1, 2, 9, 10...)

# 2. Zoxide Integration (Smart Directory Jumper)
export _ZO_ECHO=1
eval "$(zoxide init zsh)"

# ============================================================
# INTERACTIVE CLI FUNCTIONS (FZF + FD WRAPPERS)
# ============================================================

# cdv: Fuzzy directory navigation (excluding hidden directories)
cdv() {
    local dir
    dir=$(fdfind --type d --exclude '.*' | fzf --prompt="📂 Directories > " --preview "$_FZF_PREVIEW_DIR")
    [[ -n "$dir" ]] && cd "$dir"
}

# cda: Fuzzy directory navigation everywhere (including hidden, excluding .git)
cda() {
    local dir
    dir=$(fdfind --type d --hidden --exclude .git | fzf --prompt="📁 All Directories > " --preview "$_FZF_PREVIEW_DIR")
    [[ -n "$dir" ]] && cd "$dir"
}

# fv: Open a visible file in VS Code via fuzzy selector
fv() {
    local file
    file=$(fdfind --type f --exclude '.*' | fzf --prompt="📄 Files > " --preview "$_FZF_PREVIEW_CMD")
    [[ -n "$file" ]] && code "$file"
}

# fa: Open any file in VS Code via fuzzy selector (including hidden, excluding .git)
fa() {
    local file
    file=$(fdfind --type f --hidden --exclude .git | fzf --prompt="📑 All Files > " --preview "$_FZF_PREVIEW_CMD")
    [[ -n "$file" ]] && code "$file"
}

# fb: Interactive Git branch checkout
fb() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "❌ Error: Not inside a Git repository."
        return 1
    fi
    local branch
    branch=$(git branch --format='%(refname:short)' | fzf --prompt="🌿 Branches > " --preview 'git log -10 --color=always --oneline {}')
    [[ -n "$branch" ]] && git switch "$branch"
}

# fgl: Interactive Git commit log browser
fgl() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "❌ Error: Not inside a Git repository."
        return 1
    fi
    local commit
    commit=$(git log --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" | \
        fzf --ansi --no-sort --reverse --tiebreak=index --prompt="🔍 Commits > " \
        --preview 'git show --color=always {1}')

    [[ -n "$commit" ]] && git show $(echo "$commit" | awk '{print $1}')
}
