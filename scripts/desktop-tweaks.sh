#!/usr/bin/env bash
# Same system tweaks for desktop version of Ubuntu.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Perform same tweaks on desktop version of Ubuntu OS:
    * disable splash boot screen
    * disable MetaTracer service
OPTION:
    -D      Print commands, don't execute them.
    -h      Show this message.

EOF
    exit 1
}

function _eval() {
    echo "$1"; [ -z "$UBU_SETUP_DRY" ] && eval "$1";
    return $?
}
# Get modification time of specified file.
function get_modtime() { stat -c %Y "$1"; return 0; }

# Process arguments.
while getopts ":hD" OPTION; do
    case $OPTION in
        D) UBU_SETUP_DRY=1;;
        h) show_usage;;
    esac
done

# Disable animated boot logo.
echo "==> Disable splash image on boot screen."
grub_file=/etc/default/grub
_eval "sudo sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/s/\(quiet \)\?splash/verbose/g' \
    $grub_file"
_eval "sudo update-grub > /dev/null 2>&1"

# Disable Tracker.
if which tracker > /dev/null 2>&1; then
    echo "==> Disable desktop MetaTracer. (wiki.ubuntu.com/Tracker)"
    for track_file in /etc/xdg/autostart/tracker*desktop; do
        if [ -f $track_file ] && ! grep -q '^Hidden=' $track_file; then
            _eval "printf '\nHidden=true\n' | sudo tee --append $track_file > /dev/null"
        elif [ -f $track_file ]; then
            _eval "sudo sed -i '/^Hidden=/c Hidden=true' $track_file"
        fi
    done
    _eval "gsettings set org.freedesktop.Tracker.Miner.Files crawling-interval -2"
    _eval "gsettings set org.freedesktop.Tracker.Miner.Files enable-monitors false"
    _eval "tracker reset --hard"
fi

exit 0
