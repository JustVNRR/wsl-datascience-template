# ============================================================
# PROJECT SCAFFOLDING (FNEW)
# ============================================================
# This file is the pack's: the socle reads it where it lives
# (~/.config/packs/scaffold/zsh/scaffold.zsh) and copies nothing anywhere. It
# reads the catalogs of every installed pack, one per pack, and the folder that
# holds them is resolved from this file rather than from a directory of the
# socle's - `%x` is the file currently being read, which is also the right
# answer from inside a function (there, `$0` is the function's own name).

# uv - and the tools `uvx` takes from its cache - live in ~/.local/bin. The pack
# declares its own PATH rather than editing the shell's startup files, so a
# removal has nothing to undo in yours; the python pack declares the same line,
# both of them running uv.
export PATH="$HOME/.local/bin:$PATH"

# Interactively fuzzy-select a project template from every installed pack's
# catalog (packs/*/cheatsheets/templates.tsv) and print
# "url<TAB>tool<TAB>version<TAB>pack" - the pack being the one whose after-copy
# step runs once the template is in place.
_ftemplate_select() {
    # ...:A resolves the path (symlinks, `..`), :h three times climbs from
    # zsh/scaffold.zsh to the folder of the packs - this one and its neighbours,
    # each with its own catalog beside its own files.
    local packs="${${(%):-%x}:A:h:h:h}"
    local -a catalogs readable
    local skipped c

    catalogs=("$packs"/*/cheatsheets/templates.tsv(N))
    # A pack that ships no catalog is not a failure, and neither is one whose
    # catalog is empty: what the picker needs is a file to read somewhere.
    # Nothing readable anywhere at all is the silent exit fnew relies on.
    for c in "${catalogs[@]}"; do
        [[ -s "$c" ]] || continue
        readable+=("$c")
    done
    (( ${#readable} )) || return 1

    # Rows the picker will skip, collected BEFORE it runs: the warning is printed
    # once it closes. fzf owns the whole screen while it is open, so a message
    # emitted before it would only flash. Each row is named with the catalog it
    # was read from: there is more than one now.
    skipped=$(awk -F'\t' '
        /^[[:space:]]*(#|$)/ { next }
        NF < 4 { print FILENAME ": " $0 }
    ' "${readable[@]}")

    awk -F'\t' '
        # Which pack a row comes from is the folder its catalog sits in:
        # <packs>/<pack>/cheatsheets/templates.tsv. FILENAME changes with every
        # file awk opens, so this is read once per file, on its first line.
        FNR == 1 {
            n = split(FILENAME, dirs, "/")
            pack = dirs[n-2]
        }

        # Skip comments, blank lines and malformed rows (the caller warns)
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

            # Held until END: the columns are padded to the widest row, which is
            # only known once the whole catalog has been read. fzf is handed the
            # list in one go, so buffering the rows costs nothing.
            i = ++count
            urls[i] = url; tools[i] = tool; vers[i] = ver
            descs[i] = $4; repos[i] = repo; packs[i] = pack
            labels[i] = (ver == "") ? tool : tool " @" ver
            if (length(labels[i]) > wlabel) wlabel = length(labels[i])
            if (length(repo) > wrepo) wrepo = length(repo)
            if (length(pack) > wpack) wpack = length(pack)
        }

        END {
            for (i = 1; i <= count; i++) {
                if (vers[i] == "") {
                    tag = sprintf("\033[36m%s\033[0m%s", tools[i], spaces(wlabel - length(tools[i])))
                } else {
                    tag = sprintf("\033[36m%s\033[0m \033[33m@%s\033[0m%s", tools[i], vers[i], spaces(wlabel - length(labels[i])))
                }
                # Field 4 is the pack, kept out of the display on purpose: fzf
                # shows field 5 and hands the whole line back, so the pack
                # survives the pipe without being read by the eye twice.
                printf "%s\t%s\t%s\t%s\t\033[90m%s\033[0m%s \033[90m·\033[0m %s  \033[90m|\033[0m  %s%s  \033[90m|\033[0m  %s\n", urls[i], tools[i], vers[i], packs[i], packs[i], spaces(wpack - length(packs[i])), tag, repos[i], spaces(wrepo - length(repos[i])), descs[i]
            }
        }

        # n spaces; a printf of a negative width right-aligns, so it is clamped
        function spaces(k) { return sprintf("%*s", k > 0 ? k : 0, "") }
    ' "${readable[@]}" |
        fzf \
            --ansi \
            --delimiter=$'\t' \
            --with-nth=5 \
            --prompt='🏗️  Templates > ' \
            --info=inline \
            --layout=reverse |
        awk -F'\t' '{ print $1 "\t" $2 "\t" $3 "\t" $4 }'

    # A malformed row silently vanishes from the picker, which then looks exactly
    # like an empty catalog: name it, now that the screen is ours again. The row
    # printed carries the catalog it was read from.
    if [[ -n "$skipped" ]]; then
        local -a lines
        lines=("${(f)skipped}")
        printf "⚠️  %d malformed row(s) ignored\n" "${#lines}" >&2
        printf "    %s\n" "${lines[1]}" >&2
        printf "    A row needs 4 TAB-separated columns: url, tool, version, description.\n" >&2
    fi
}

# Scaffold a new project, from the packs' catalogs or from an explicit URL
# 1. Fail fast: fnew only runs from ~/projects itself (before any input)
# 2. Template: the first argument, or fuzzy-picked from the catalogs
# 3. Enter the project name
# 4. Delegate to the gmake Makefile (copier_project / cruft_project / ccds_project)
#    to run the pack's after-copy step defined there
#
#   fnew                        # pick from the catalogs
#   fnew gh:owner/repo          # try a template that is not in the catalog
#   fnew gh:owner/repo cruft v1 # ...with the other tool (default: copier) and a pinned ref
#
# The URL form reads and writes nothing: a template that turns out not to suit
# costs only the project directory, and the catalogs stay the short list of
# what was worth keeping.
fnew() {
    local selection url tool version project_name pack remainder
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
        remainder=${remainder#*$'\t'}
        version=${remainder%%$'\t'*}
        pack=${remainder#*$'\t'}
    fi

    if [[ "$tool" != copier && "$tool" != cruft && "$tool" != ccds ]]; then
        echo "❌ Unknown scaffold tool '$tool' (expected: copier, cruft or ccds)" >&2
        return 1
    fi

    while true; do
        read "project_name?Project folder: "
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
    # The pack the row came from decides what runs once the template is copied,
    # and naming it on the make command line beats the .env.global default that
    # a direct call reads. The URL form names none: it picked no row, so it
    # keeps that default.
    if [[ -n "$pack" ]]; then
        make_args+=("TEMPLATE_PACK=$pack")
    fi

    # The makefile cannot move this shell: its recipes run in their own, and a
    # process cannot change its parent's directory. fnew is a function, so it
    # can - and it does it only when the scaffolding succeeded.
    make -f "$ZDOTDIR/gmake/Makefile" "${make_args[@]}" && cd "$project_name"
}
