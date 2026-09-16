# ============================================================
# PROJECT SCAFFOLDING (FNEW)
# ============================================================

# Interactively fuzzy-select a project template from the catalog
# ($ZDOTDIR/cheatsheets/templates.tsv) and print "url<TAB>tool<TAB>version"
_ftemplate_select() {
    local catalog="$ZDOTDIR/cheatsheets/templates.tsv"

    # Silent exit when the catalog is missing or empty
    [[ -s "$catalog" ]] || return 1

    awk -F'\t' '
        # Skip comments, blank lines, and malformed rows
        /^[[:space:]]*(#|$)/ { next }
        NF < 4 { next }
        {
            url = $1
            tool = $2
            ver = $3
            sub(/[[:space:]]+$/, "", url)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", tool)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", ver)
            sub(/^[[:space:]]+/, "", $4)

            # Derive owner/repo from the url so the picker is searchable by repo name
            n = split(url, seg, "/")
            repo = url
            if (n >= 2) {
                repo = seg[n-1] "/" seg[n]
                sub(/^gh:/, "", repo)
                sub(/\.git$/, "", repo)
            }

            if (ver == "") {
                tag = sprintf("\033[36m%-7s\033[0m", tool)
            } else {
                tag = sprintf("\033[36m%-7s\033[0m \033[33m@%s\033[0m", tool, ver)
            }
            printf "%s\t%s\t%s\t%s \033[90m|\033[0m %s \033[90m|\033[0m %s\n", url, tool, ver, tag, repo, $4
        }
    ' "$catalog" |
        fzf \
            --ansi \
            --delimiter=$'\t' \
            --with-nth=4 \
            --prompt='🏗️  Templates > ' \
            --info=inline \
            --layout=reverse |
        awk -F'\t' '{ print $1 "\t" $2 "\t" $3 }'
}

# Scaffold a new project from the template catalog
# 1. Fail fast: confirm the location when outside ~/projects (before any input)
# 2. Fuzzy-pick a template (description shown, url + pinned version kept as data)
# 3. Enter the project name
# 4. Delegate to the global Makefile (copier_project / cruft_project)
#    to reuse the venv + direnv bootstrap defined there
fnew() {
    local selection url tool version project_name remainder reply
    local -a make_args

    # Destination guard: fail fast, before any interaction, when scaffolding
    # outside ~/projects (the full destination is echoed again before make)
    if [[ "$PWD" != "$HOME"/projects && "$PWD" != "$HOME"/projects/* ]]; then
        echo "⚠  Current directory: $PWD (outside ~/projects)"
        read "reply?Scaffold here anyway? [y/N] "
        if [[ "$reply" != [yY] ]]; then
            echo "❌ Aborted by user."
            return 1
        fi
    fi

    selection=$(_ftemplate_select)
    [[ -z "$selection" ]] && return

    url=${selection%%$'\t'*}
    remainder=${selection#*$'\t'}
    tool=${remainder%%$'\t'*}
    version=${remainder##*$'\t'}

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

    echo "📁 Creating project in: $PWD/$project_name"

    make_args=("${tool}_project" "PROJECT_NAME=$project_name" "PROJECT_TEMPLATE_REPO=$url")
    if [[ -n "$version" ]]; then
        make_args+=("PROJECT_TEMPLATE_VERSION=$version")
    fi

    make -f "$ZDOTDIR/cheatsheets/global_makefile.mk" "${make_args[@]}"
}
