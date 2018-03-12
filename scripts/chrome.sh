#!/usr/bin/env bash
# Install Google Chrome browser.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest stable version Google Chrome web browser.
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

# Process arguments.
while getopts ":hD" OPTION; do
    case $OPTION in
        D) UBU_SETUP_DRY=1;;
        h) show_usage;;
    esac
done

# Check if system has GUI layer.
dpkg -l 2> /dev/null | grep -q "xserver-xorg\s"
if [ $? -ne 0 ]; then
    echo "Error: Operating system does not have graphical component."
    echo "       Abort Google Chrome installation."
    exit 1
elif google-chrome --version > /dev/null 2>&1; then
    echo "Error: Google Chrome is already installed."
    echo "       Abort Google Chrome installation."
    exit 1
fi

# Add Google Chrome APT repository to source list if needed.
grep -qi --include=*\.list -e "^deb .\+google.\+chrome" /etc/apt/sources.list /etc/apt/sources.list.d/*
if [ $? -ne 0 ]; then
    echo "==> Add Google Chrome APT repository."
    _eval "wget -qO - https://dl-ssl.google.com/linux/linux_signing_key.pub | \
        sudo apt-key add -"
    _eval "echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' \
        | sudo tee --append /etc/apt/sources.list.d/google-chrome.list > /dev/null"
    _eval "sudo apt-get update -qq"
fi

echo "==> Install Google Chrome stable branch."
_eval "sudo apt-get install -qq google-chrome-stable"
