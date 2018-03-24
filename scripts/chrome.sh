#!/usr/bin/env bash
# Install Google Chrome browser.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest stable version of Google Chrome web browser.
OPTION:
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Google Chrome installation.'
    exit ${2:-1}
}

# Process arguments.
while getopts ":h" OPTION; do
    case $OPTION in
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126

# Check if system has GUI layer.
dpkg -l 2> /dev/null | grep -q 'xserver-xorg\s'
if [ $? -ne 0 ]; then
    _exit 'Operating system does not have graphical component.' 126
elif google-chrome --version > /dev/null 2>&1; then
    _exit 'Google Chrome is already installed.'
elif chromium-browser --version > /dev/null 2>&1; then
    echo '==> Delete Chromium Browser.'
    sudo apt-get purge -qq chromium-browser
fi

# Add Google Chrome APT repository to source list if needed.
grep -qi --include=*\.list -e '^deb .\+google.\+chrome' \
    /etc/apt/sources.list /etc/apt/sources.list.d/*
if [ $? -ne 0 ]; then
    echo '==> Add Google Chrome APT repository.'
    wget -qO - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    [ $? -ne 0 ] && _exit 'Fail to add key for Google Chrome repository.'
    echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' | \
        sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
    sudo apt-get update -qq
fi

echo '==> Install Google Chrome stable branch.'
sudo apt-get install -qq google-chrome-stable
