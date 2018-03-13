#!/usr/bin/env bash
# Script removes useless packages that comes pre-installed with Ubuntu.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Remove packages that comes pre-installed with Ubuntu OS.
OPTION:
    -h      Show this message.

EOF
    exit 1
}

while getopts ":h" OPTION; do
    case $OPTION in
        h) show_usage;;
    esac
done

# Remove Gnome pre-installed applications.
echo "==> Remove Gnome pre-installed packages."
declare -a pkg_list=('audio' 'blog' 'calculator' 'calendar' 'dictionary' \
    'documents' 'games' 'games-app' 'gmail' 'chess' 'hearts' 'mahjongg' \
    'maps' 'mines' 'music' 'photos' 'recipes' 'sound-recorder' \
    'sudoku' 'todo' 'translate' 'weather')
pkg_str=$(printf ",%s" "${pkg_list[@]}")
eval "sudo apt-get purge -qq gnome-{${pkg_str:1}}"
unset pkg_list pkg_str

# Remove Mozilla software.
echo "==> Remove Mozilla applications."
sudo apt-get purge -qq firefox thunderbird

# Delete pre-installed media applications.
echo "==> Remove default media applications."
sudo apt-get purge -qq rhythmbox rhythmbox-data totem

# Delete other garbage.
echo "Remove the rest of pre-installed packages."
sudo apt-get purge -qq xterm imagemagick deja-dup vim-tiny \
    shotwell shotwell-common transmission-common yelp*

# Clean-up.
sudo apt-get autoremove -qq
