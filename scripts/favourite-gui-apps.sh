#!/usr/bin/env bash
# Install my favourite applications for desktop.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install software for desktop Ubuntu.
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

# Check if OS has GUI layer.
dpkg -l 2> /dev/null | grep -q "xserver-xorg\s"
if [ $? -ne 0 ]; then
    echo "Error: Operating system does not have graphical component."
    echo "       Abort installation of GUI applications."
    exit 1
fi

echo "==> Install audio and video player."
sudo apt-get update -qq
# Check if gnome desktop.
dpkg -l 2> /dev/null | grep -qi "gnome-\?desktop"
[ $? -eq 0 ] && sudo apt-get install -qq gnome-shell-extension-mediaplayer
sudo apt-get install -qq clementine vlc

echo "==> Install rest of favourites."
sudo apt-get install -qq qbittorrent
#_eval "sudo apt-get install -qq --no-install-recommends meld"
