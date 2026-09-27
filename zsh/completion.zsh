# ============================================================
# COMPLETION
# ============================================================

# The targets `gmake` takes, each with the sentence it carries. Read at every
# Tab from the files the help menu is built from - the Makefile and the modules
# it includes, the socle's and every installed pack's - with the help menu's own
# rule: a target documents itself after `##`. So Tab offers what `gmake help`
# prints, in the same order, and a pack that is not installed brings neither a
# module here nor a target. Nothing is written down twice: a target's name and
# its sentence are read from the line that already holds them.
_gmake() {
    local -a files pairs

    # The first word only: what follows a target is an assignment (`VAR=value`)
    # or nothing, and file names there would only be in the way.
    (( CURRENT == 2 )) || return 1

    # The Makefile, its modules, the packs' - the same three places `help` reads.
    files=("$ZDOTDIR"/gmake/Makefile(N) "$ZDOTDIR"/gmake/make/*.mk(N) "$ZDOTDIR"/../packs/*/make/*.mk(N))
    (( $#files )) || return 1

    # `name:sentence`, the form _describe reads, built by the expression the help
    # rule uses: `:.*##` is one field separator, so $1 is the target and $2 what
    # follows its `##`. Sorted like the menu - the two lists are meant to be read
    # as one.
    pairs=(${(f)"$(
        awk -F':.*##' '
            /^[a-zA-Z_-]+:.*?##/ {
                sub(/[[:space:]]+$/, "", $2)
                printf "%s:%s\n", $1, $2
            }
        ' "${files[@]}" | sort -f
    )"})
    (( $#pairs )) || return 1

    _describe -t gmake-targets 'gmake target' pairs
}

# On the name, once the function above is defined - not on `make`, which is a
# command of its own, with its own Makefile to read.
compdef _gmake gmake
