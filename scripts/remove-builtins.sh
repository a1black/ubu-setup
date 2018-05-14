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
    'sudoku' 'todo' 'translate' 'weather')
for pkg_name in ${pkg_list[@]}; do
    sudo apt-get purge -qq gnome-$pkg_name
done

# Remove Xfce pre-installed applications.
echo '==> Remove pre-installed Xfce packages.'
declare -a pkg_list=('xfburn' xfce4-dict' 'xfce4-notes' 'xfce4-screenshooter' 'mousepad')

# Remove pre-installed web applications.
echo '==> Remove pre-installed internet applications.'
declare -a pkg_list=('firefox' 'thunderbird' 'chromium' 'pidgin' \
    'transmission-common' 'gigolo')
for pkg_name in ${pkg_list[@]}; do
    sudo apt-get purge -qq $pkg_name
done

# Delete pre-installed media applications.
echo '==> Remove default media applications.'
declare -a pkg_list=('rhythmbox' 'rhythmbox-data' 'totem' 'parole')
for pkg_name in ${pkg_list[@]}; do
    sudo apt-get purge -qq $pkg_name
done

# Delete other pre-installed applications.
echo '==> Remove the rest of pre-installed packages.'
declare -a pkg_list=('aisleriot' 'sgt-puzzles' 'cheese' \
    'remmina' 'remmina-common' 'deja-dup' 'simple-scan' \
    'catfish' 'imagemagick' 'shotwell' 'shotwell-common' \
    'onboard' 'onboard-common' 'yelp*')
for pkg_name in ${pkg_list[@]}; do
    sudo apt-get purge -qq $pkg_name
done

# Clean-up.
echo '==> Remove unneeded dependencies.'
sudo apt-get autoremove -qq

unset pkg_list pkg_name
