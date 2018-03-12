#!/usr/bin/env bash
# Install VirtualBox package.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest available version of VirtualBox.
OPTION:
    -p      Default path to store images of virtual machines.
    -D      Print command, don't execute them.
    -h      Show this message.

EOF
    exit 1
}

function _eval() {
    echo "$1"; [ -z "$UBU_SETUP_DRY" ] && eval "$1";
    return $?
}
function _exit () {
    echo "Error: $1";
    echo "       Abort VirtualBox installation."
    exit 1
}

# Process arguments.
while getopts ":hDp:" OPTION; do
    case $OPTION in
        p) vm_path="$OPTARG";;
        D) UBU_SETUP_DRY=1;;
        h) show_usage;;
    esac
done

# Default values.
[ -z "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER

# Check if VirtualBox is already installed.
if which virtualbox > /dev/null 2>&1; then
    _exit "VirtualBox is already installed."
fi

sys_codename=$(lsb_release -c | cut -f 2)
sys_release=$(lsb_release -r | cut -f 2)

# Add Oracle VirtualBox APT repository to source list.
grep -qi --include=*\.list -e "^deb .\+virtualbox" /etc/apt/sources.list /etc/apt/sources.list.d/*
if [ $? -ne 0 ]; then
    echo "==> Add Oracle VirtualBox APT repository."
    if [[ 16.04 > $sys_release ]]; then
        key_uri="https://www.virtualbox.org/download/oracle_vbox.asc"
    else
        key_uri="https://www.virtualbox.org/download/oracle_vbox_2016.asc"
    fi
    _eval "wget -qO - $key_uri | sudo apt-key add -"
    _eval "echo 'deb https://download.virtualbox.org/virtualbox/debian $sys_codename contrib' | \
        sudo tee --append /etc/apt/sources.list.d/oracle-virtualbox.list > /dev/null"
    _eval "sudo apt-get update -qq"
fi

# Determine latest stable version of VirtualBox.
install_ver=$(wget -qO - "https://download.virtualbox.org/virtualbox/LATEST-STABLE.TXT"\
    | grep --color=never -o "[0-9]\+\.[0-9]\+" | head -n 1)
if [ $? -ne 0 ]; then
    _exit "Fail retrieve number of latest VirtualBox version."
fi

echo "==> Install VirtualBox package."
_eval "sudo apt-get install -qq virtualbox-$install_ver"

# Try to change default path for virtual machines.
if [ -n "$vm_path" ]; then
    vb_config="/home/$cuser/.config/VirtualBox/VirtualBox.xml"
    vb_cmd="sed -i 's#\(defaultMachineFolder=\)\"[^\"]\+\"#\1\"$vm_path\"#'"
    if [ ! -f "$vb_config" ]; then
        echo "You can change virtual machine default path in GUI or running command:"
        echo "  $vb_cmd ~/.config/VirtualBox/VirtualBox.xml"
    elif [[ -e "$vm_path" && ! -d "$vm_path" ]]; then
        echo "Provided path \"$vm_path\" isn't directory."
    elif [ ! -d "$vm_path" ]; then
        echo "Directory \"$vm_path\" does not exist."
    else
        _eval "$vb_cmd $vb_config"
    fi
fi
