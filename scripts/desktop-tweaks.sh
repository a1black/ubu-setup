#!/usr/bin/env bash
# Same system tweaks for desktop version of Ubuntu.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Perform same tweaks on desktop version of Ubuntu OS:
    * disable splash boot screen
    * disable MetaTracer service
    * disable all Gnome extensions
    * disable bluetooth
OPTION:
    -h      Show this message.

EOF
    exit 1
}

# Get modification time of specified file.
function get_modtime() { stat -c %Y "$1"; return 0; }

# Process arguments.
while getopts ":h" OPTION; do
    case $OPTION in
        *) show_usage;;
    esac
done

# Check privileges.
if [ $UID -ne 0 ]; then
    echo 'Error: Run script with root privileges.'
    exit 126
fi

# Disable animated boot logo.
echo '==> Disable splash image on boot screen.'
sudo sed -i.orig '/^GRUB_CMDLINE_LINUX_DEFAULT/s/\(quiet \)\?splash//g' \
    /etc/default/grub
sudo update-grub > /dev/null 2>&1

# Disable Tracker.
if which tracker > /dev/null 2>&1; then
    echo '==> Disable desktop MetaTracer. (wiki.ubuntu.com/Tracker)'
    for track_file in /etc/xdg/autostart/tracker*desktop; do
        if [ -f $track_file ] && ! grep -q '^Hidden=' $track_file; then
            printf '\nHidden=true\n' | sudo tee --append $track_file > /dev/null
        elif [ -f $track_file ]; then
            sudo sed -i '/^Hidden=/c Hidden=true' $track_file
        fi
    done
    gsettings set org.freedesktop.Tracker.Miner.Files crawling-interval -2
    gsettings set org.freedesktop.Tracker.Miner.Files enable-monitors false
    tracker reset --hard
fi

# Remove some web launchers from desktop.
launchers=('amazon')
for launcher_name in ${launchers[@]}; do
    sudo find /usr/share -iname "*$launcher_name*\.desktop" -exec rm '{}' \; -o -iname "*$launcher_name-launcher*" -exec rm '{}' \;
done

# Disable Gnome shell extensions.
if gnome-shell-extension-tool -h > /dev/null 2>&1; then
    echo '==> Disable global Gnome shell extensions.'
    for filename in /usr/share/gnome-shell/extensions/*; do
        [ ! -e "$filename" ] && continue
        extension=$(basename ${filename%%@*})
        gnome-shell-extension-tool -d $extension
    done
#    echo '==> Disable local Gnome shell Extensions.'
#    for filename in ~/.local/share/gnome-shell/extensions/*; do
#        [ ! -e "$filename" ] && continue
#        extension=$(basename ${filename%%@*})
#        gnome-shell-extension-tool -d $extension
#    done
fi

# Disable Bluetooth service.
if systemctl --version > /dev/null 2>&1; then
    echo '==> Disable Blutooth Service.'
    sudo systemctl stop bluetooth
    sudo systemctl disable bluetooth
fi

# Disable Whoopsie service.
echo "==> Uninstall Whoopsie Service."
sudo apt-get purge -qq whoopsie
