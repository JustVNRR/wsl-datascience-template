# ============================================================
# PROJECT SCAFFOLDING (FNEW)
# ============================================================

# Interactively fuzzy-select a project template from the catalog
# ($ZDOTDIR/cheatsheets/templates.tsv) and print "url<TAB>tool"
_ftemplate_select() {
    local catalog="$ZDOTDIR/cheatsheets/templates.tsv"

    # Silent exit when the catalog is missing or empty
    [[ -s "$catalog" ]] || return 1

    awk -F'\t' '
        # Skip comments, blank lines, and malformed rows
        /^[[:space:]]*(#|$)/ { next }
        NF < 3 { next }
        {
            url = $1
            tool = $2
            sub(/[[:space:]]+$/, "", url)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", tool)
            sub(/^[[:space:]]+/, "", $3)
            printf "%s\t%s\t\033[36m%-7s\033[0m \033[90m|\033[0m %s\n", url, tool, tool, $3
        }
    ' "$catalog" |
        fzf \
            --ansi \
            --delimiter=$'\t' \
            --with-nth=3 \
            --prompt='🏗️  Templates > ' \
            --info=inline \
            --layout=reverse |
        awk -F'\t' '{ print $1 "\t" $2 }'
}

# Scaffold a new project from the template catalog
# 1. Fuzzy-pick a template (description shown, url kept as data)
# 2. Enter the project name
# 3. Delegate to the global Makefile (copier_project / cruft_project)
#    to reuse the venv + direnv bootstrap defined there
fnew() {
    local selection url tool project_name

    selection=$(_ftemplate_select)
    [[ -z "$selection" ]] && return

    url=${selection%%$'\t'*}
    tool=${selection##*$'\t'}

    if [[ "$tool" != copier && "$tool" != cruft ]]; then
        echo "Unknown scaffold tool '$tool' in templates.tsv (expected: copier or cruft)" >&2
        return 1
    fi

    while true; do
        read "project_name?Project name: "
        if [[ "$project_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
            break
        fi
        echo "Invalid name (use letters, digits, '.', '_' or '-'; no spaces)."
    done

    make -f "$ZDOTDIR/cheatsheets/global_makefile.mk" \
        "${tool}_project" \
        PROJECT_NAME="$project_name" \
        PROJECT_TEMPLATE_REPO="$url"
}
