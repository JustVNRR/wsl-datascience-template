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
        # Skip comments and blank lines
        /^[[:space:]]*(#|$)/ { next }

        # A malformed row silently vanishes from the picker, which then looks
        # exactly like an empty catalog: count it and warn in END, on stderr
        # (stdout is the candidate list fzf is reading).
        NF < 4 { malformed++; if (!example) example = $0; next }

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

        END {
            if (malformed) {
                printf "⚠️  %d malformed row(s) ignored in %s\n", malformed, FILENAME > "/dev/stderr"
                printf "    %s\n", example > "/dev/stderr"
                printf "    A row needs 4 TAB-separated columns: url, tool, version, description.\n" > "/dev/stderr"
            }
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

# Scaffold a new project, from the template catalog or from an explicit URL
# 1. Fail fast: fnew only runs from ~/projects itself (before any input)
# 2. Template: the first argument, or fuzzy-picked from the catalog
# 3. Enter the project name
# 4. Delegate to the global Makefile (copier_project / cruft_project)
#    to reuse the venv + direnv bootstrap defined there
#
#   fnew                        # pick from the catalog
#   fnew gh:owner/repo          # try a template that is not in the catalog
#   fnew gh:owner/repo cruft v1 # ...with the other tool (default: copier) and a pinned ref
#
# The URL form reads and writes nothing: a template that turns out not to suit
# costs only the project directory, and the catalog stays the short list of
# what was worth keeping.
fnew() {
    local selection url tool version project_name remainder
    local -a make_args

    # Destination guard: fail fast, before any interaction — projects are
    # scaffolded from ~/projects itself (deeper would nest projects)
    if [[ "$PWD" != "$HOME"/projects ]]; then
        echo "❌ fnew runs from ~/projects itself (current: $PWD)" >&2
        return 1
    fi

    if [[ -n "$1" ]]; then
        url="$1"
        tool="${2:-copier}"
        version="${3:-}"
    else
        selection=$(_ftemplate_select)
        [[ -z "$selection" ]] && return

        url=${selection%%$'\t'*}
        remainder=${selection#*$'\t'}
        tool=${remainder%%$'\t'*}
        version=${remainder##*$'\t'}
    fi

    if [[ "$tool" != copier && "$tool" != cruft ]]; then
        echo "❌ Unknown scaffold tool '$tool' (expected: copier or cruft)" >&2
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

    make -f "$ZDOTDIR/gmake/global_makefile.mk" "${make_args[@]}"
}
