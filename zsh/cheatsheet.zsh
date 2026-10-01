# ============================================================
# CHEATSHEETS (FCHEAT)
# ============================================================

# The cheatsheets the picker should offer, minus those whose `# requires:`
# header is not met. The condition can be negated - `# requires: !gcloud` hides
# the sheet when the tool IS there, which is what a sheet about installing that
# tool wants. Nothing is recorded: the question is asked again every time the
# picker opens, the way `gmake` asks it at every run.
#
# Two folders, one rule: the socle's sheets, then the packs' - the same place
# the gmake Makefile looks for a pack, so a pack added later brings its sheets
# with it and this file never learns its name.
_fcheat_files() {
    local file requires binary

    for file in "$ZDOTDIR"/cheatsheets/*.sh(N) "$ZDOTDIR"/../packs/*/cheatsheets/*.sh(N); do
        requires=$(awk '/^#[[:space:]]*requires:/ {
            sub(/^#[[:space:]]*requires:[[:space:]]*/, "")
            sub(/[[:space:]]+$/, "")
            print
            exit
        }' "$file")

        if [[ -z "$requires" ]]; then
            print -r -- "$file"
        elif [[ "$requires" == '!'* ]]; then
            binary=${requires#!}
            command -v "$binary" >/dev/null 2>&1 || print -r -- "$file"
        elif command -v "$requires" >/dev/null 2>&1; then
            print -r -- "$file"
        fi
    done
}

# Interactively fuzzy-select a command via fzf and return only the raw command
_fcheat_select() {
    local raw
    local -a sheets

    raw=$(_fcheat_files)
    [[ -z "$raw" ]] && return 1
    sheets=("${(@f)raw}")

    awk -F'#' -v c="$C_CYAN" -v m="$C_GREY" -v r="$C_RESET" '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ {
            next
        }

        {
            command = $1
            description = $2

            sub(/[[:space:]]+$/, "", command)
            sub(/^[[:space:]]+/, "", description)

            printf "%s\t%s%-40s%s | %s%s\n",
                command, c, command, m, r, description
        }
    ' "${sheets[@]}" 2>/dev/null |
        sort -f -t $'\t' -k1,1V |
        # Exact matching, not fzf's fuzzy default: the default takes the letters
        # of the query in order, anywhere in the line, so a word also matches
        # lines that merely spell it out at a distance. Measured on this
        # repository's own sheets, a query for `docker` ended its list on
        # `fnew`, `ping <DOMAIN_OR_IP>`, `gcloud auth login` and
        # `sudo apt upgrade` - none of which is a docker command - where exact
        # matching keeps the docker ones and nothing else. What fuzzy was good
        # at, a fragment like `dckr`, is gone with it: that is the trade. `'`
        # and `!` behave as they always did.
        fzf \
            --exact \
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

# ZLE Widget: Alt + z
# Replace prompt buffer with the selected cheatsheet command
_fcheat_widget() {
    local command

    # -I before the picker, reset-prompt after: see the note in aliases.zsh
    # (_falias_widget). fzf overwrites the bottom of the screen, and zsh has
    # to be told before it redraws the prompt over what it still believes is
    # there.
    zle -I
    command=$(_fcheat_select)

    [[ -z "$command" ]] && {
        zle reset-prompt
        return
    }

    LBUFFER="$command"
    RBUFFER=""
    zle reset-prompt
}
