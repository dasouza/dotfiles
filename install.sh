#!/bin/sh
# Symlink everything under .config/ in this repo into ~/.config.
# Existing files/dirs that aren't already our symlinks are moved to <name>.pre-dotfiles first.
set -eu

repo=$(cd "$(dirname "$0")" && pwd)
target="${XDG_CONFIG_HOME:-$HOME/.config}"

# Top-level entries are linked as a whole, except xdg-desktop-portal, which is linked per file
# because other packages may drop their own portal configs next to ours.
link() {
    src=$1 dst=$2
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        echo "ok      $dst"
        return
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mv "$dst" "$dst.pre-dotfiles"
        echo "backup  $dst -> $dst.pre-dotfiles"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "link    $dst -> $src"
}

for entry in "$repo"/.config/*; do
    name=$(basename "$entry")
    case "$name" in
    xdg-desktop-portal)
        for f in "$entry"/*; do link "$f" "$target/$name/$(basename "$f")"; done ;;
    *)
        link "$entry" "$target/$name" ;;
    esac
done
