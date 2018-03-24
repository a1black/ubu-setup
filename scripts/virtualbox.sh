#!/usr/bin/env bash
# Install VirtualBox package.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest available version of VirtualBox.
OPTION:
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort VirtualBox installation.'
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
# Check if VirtualBox is already installed.
virtualbox --help > /dev/null 2>&1 && _exit 'VirtualBox is already installed.'
# Check if system has GUI layer.
dpkg -l 2> /dev/null | grep -q 'xserver-xorg\s'
[ $? -ne 0 ] && _exit 'Operating system does not have graphical component.' 126

codename=$(lsb_release -cs 2> /dev/null)
os_release=$(lsb_release -rs 2> /dev/null)
[ $? -ne 0 ] && _exit 'Fail to determine OS codename.' 127

# Add Oracle VirtualBox APT repository to source list.
grep -qi --include=*\.list -e '^deb .\+virtualbox' \
    /etc/apt/sources.list /etc/apt/sources.list.d/*
if [ $? -ne 0 ]; then
    echo '==> Add Oracle VirtualBox APT repository.'
    if [[ 16.04 > $os_release ]]; then
        key_uri='https://www.virtualbox.org/download/oracle_vbox.asc'
    else
        key_uri='https://www.virtualbox.org/download/oracle_vbox_2016.asc'
    fi
    wget -qO - $key_uri 2> /dev/null | sudo apt-key add -
    [ $? -ne 0 ] && _exit 'Fail to add key for VirtualBox repository.'
    echo "deb https://download.virtualbox.org/virtualbox/debian $codename contrib" | \
        sudo tee /etc/apt/sources.list.d/oracle-virtualbox.list > /dev/null
    sudo apt-get update -qq
fi

# Determine latest stable version of VirtualBox.
latest_version_uri='https://download.virtualbox.org/virtualbox/LATEST-STABLE.TXT'
install_ver=$(wget -qO - $latest_version_uri 2> /dev/null | \
    grep --color=never -o '[0-9]\+\.[0-9]\+')
[ $? -ne 0 ] && _exit 'Fail retrieve number of latest VirtualBox version.'

# Install VirtualBox.
echo '==> Install VirtualBox package.'
sudo apt-get install -qq virtualbox-$install_ver

cat << EOF
You can change virtual machine default path in GUI or running command:
    sed -i.orig 's#\(defaultMachineFolder\)="[^"]\+"#\1="~/vmdisk"#'
EOF
