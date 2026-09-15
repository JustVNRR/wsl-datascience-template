# ============================================================
# CHEATSHEETS (FCHEAT)
# ============================================================

# Interactively fuzzy-select a command via fzf and return only the raw command
_fcheat_select() {
    awk -F'#' '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ {
            next
        }

        {
            command = $1
            description = $2

            sub(/[[:space:]]+$/, "", command)
            sub(/^[[:space:]]+/, "", description)

            printf "%s\t\033[36m%-40s\033[90m | \033[0m%s\n",
                command, command, description
        }
    ' "$ZDOTDIR"/cheatsheets/*.sh(N) 2>/dev/null |
        sort -f -t $'\t' -k1,1V |
        fzf \
            --ansi \
            --delimiter=$'\t' \
            --with-nth=2 \
            --prompt='📘 Cheatsheets > ' \
            --info=inline \
            --layout=reverse |
        awk -F'\t' '{print $1}'
}

# Standard CLI usage: fcheat
# Select a command and load it into the prompt buffer ready to execute
fcheat() {
    local command

    command=$(_fcheat_select)

    [[ -z "$command" ]] && return

    print -z -- "$command"
}

# ZLE Widget: Ctrl + H
# Replace prompt buffer with the selected cheatsheet command
_fcheat_widget() {
    local command

    command=$(_fcheat_select)

    [[ -z "$command" ]] && {
        zle redisplay
        return
    }

    LBUFFER="$command"
    RBUFFER=""
    zle redisplay
}
