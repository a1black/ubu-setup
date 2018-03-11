#!/usr/bin/env bash
# Script removes useless packages that comes pre-installed with Ubuntu.

function show_usage() {
    cat << EOF
Usage: sudo $(basename $0) [OPTION]
Remove packages that comes pre-installed with Ubuntu OS.
OPTION:
    -D      Print command, don't execute them.
    -h      Show this message.

EOF
    exit 1
}

function _eval() {
    echo "$1"; [ -z "$UBU_SETUP_DRY" ] && eval "$1";
    return $?
}

while getopts ":hD" OPTION; do
    case $OPTION in
        D) UBU_SETUP_DRY=1;;
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
_eval "sudo apt-get purge -qq gnome-{${pkg_str:1}}"
unset pkg_list pkg_str

# Remove Mozilla software.
echo "==> Remove Mozilla applications."
_eval "sudo apt-get purge -qq firefox thunderbird"

# Delete pre-installed media applications.
echo "==> Remove default media applications."
_eval "sudo apt-get purge -qq rhythmbox rhythmbox-data totem"

# Delete other garbage.
echo "Remove the rest of pre-installed packages."
_eval "sudo apt-get purge -qq xterm imagemagick deja-dup vim-tiny \
shotwell shotwell-common transmission-common yelp*"

# Clean-up.
_eval "sudo apt-get autoremove -qq"
