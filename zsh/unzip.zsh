# ============================================================
# SMART ARCHIVE EXTRACTION UTILITY
# ============================================================

# Extracts archives into an editable dedicated directory
extract() {
    local target default_dir dest_dir remove_orig

    # Fall back to fzf interactive search if no argument is passed ($# == 0)
    if [ $# -eq 0 ]; then
        target=$(fdfind --type f -e zip -e rar -e gz -e tar -e bz2 -e 7z -e tgz -e tbz2 -e xz | fzf --prompt="📦 Select archive to extract > ")
        [[ -z "$target" ]] && return 0
    else
        target="$1"
    fi

    if [ -f "$target" ]; then
        # 1. Compute default destination folder name (stripping extensions)
        default_dir="${target%.tar.*}"
        default_dir="${default_dir%.*}"
        dest_dir="$default_dir"

        # 2. Interactive target directory prompt via ZLE (pre-filled, editable in-place)
        vared -p "📂 Destination directory: " dest_dir

        # Fall back to default name if user submits an empty string
        [[ -z "$dest_dir" ]] && dest_dir="$default_dir"

        mkdir -p "$dest_dir"
        echo "🚀 Extracting into '$dest_dir/'..."

        # 3. Targeted decompression based on file signature
        case "$target" in
            *.tar.bz2)   tar xvjf "$target" -C "$dest_dir"    ;;
            *.tar.gz)    tar xvzf "$target" -C "$dest_dir"    ;;
            *.bz2)       cp "$target" "$dest_dir/" && bunzip2 "$dest_dir/$(basename "$target")" ;;
            *.rar)       unrar x "$target" "$dest_dir/"       ;;
            *.gz)        cp "$target" "$dest_dir/" && gunzip "$dest_dir/$(basename "$target")" ;;
            *.tar)       tar xvf "$target" -C "$dest_dir"     ;;
            *.tbz2)      tar xvjf "$target" -C "$dest_dir"    ;;
            *.tgz)       tar xvzf "$target" -C "$dest_dir"    ;;
            *.zip)       unzip "$target" -d "$dest_dir"       ;;
            *.Z)         cp "$target" "$dest_dir/" && gunzip "$dest_dir/$(basename "$target")" ;;
            *.7z)        7z x "$target" -o"$dest_dir"         ;;
            *.tar.xz)    tar xvf "$target" -C "$dest_dir"     ;;
            *.xz)        cp "$target" "$dest_dir/" && unxz "$dest_dir/$(basename "$target")" ;;
            *)
                echo "❌ Unsupported archive format: '$target'" >&2
                rmdir "$dest_dir" 2>/dev/null
                return 1
                ;;
        esac

        # 4. Prompt for original archive removal
        echo -n "🗑️  Remove original archive ($target)? [y/N] "
        read -r remove_orig
        if [[ "$remove_orig" =~ ^[yY](es)?$ ]]; then
            rm -f "$target"
            echo "✅ Original archive removed."
        else
            echo "👍 Original archive kept."
        fi

    else
        echo "❌ '$target' is not a valid file." >&2
        return 1
    fi
}
