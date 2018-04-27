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
        *) show_usage;;
    esac
done

# Check privileges.
if [ $UID -ne 0 ]; then
    echo 'Error: Run script with root privileges.'
    echo '       Abort removing pre-installed packages.'
    exit 126
fi

# Remove Gnome pre-installed applications.
echo '==> Remove pre-installed Gnome packages.'
declare -a pkg_list=('audio' 'blog' 'calculator' 'calendar' 'dictionary' \
    'documents' 'games' 'games-app' 'gmail' 'chess' 'hearts' 'mahjongg' \
    'maps' 'mines' 'music' 'photos' 'recipes' 'sound-recorder' \
    'sudoku' 'todo' 'translate' 'weather' 'online-accounts')
pkg_str=$(printf ",%s" "${pkg_list[@]}")
bash -c "sudo apt-get purge -qq gnome-{${pkg_str:1}}"
unset pkg_list pkg_str

# Remove Mozilla software and other web applications.
echo '==> Remove Web applications.'
sudo apt-get purge -qq firefox thunderbird chromium

# Delete pre-installed media applications.
echo '==> Remove default media applications.'
sudo apt-get purge -qq rhythmbox rhythmbox-data totem

# Delete other garbage.
echo '==> Remove the rest of pre-installed packages.'
sudo apt-get purge -qq xterm imagemagick deja-dup vim-tiny cheese \
    simple-scan shotwell shotwell-common transmission-common remmina-common \
    aisleriot yelp*

# Clean-up.
echo '==> Remove unneeded dependencies.'
sudo apt-get autoremove -qq
