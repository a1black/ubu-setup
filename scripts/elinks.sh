#!/usr/bin/env bash
# Install command-line browser Elinks.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install command-line browser Elinks.
OPTION:
    -u      Configure Elinks for provided user (default current user).
    -c      Download link for Elinks configuration file.
    -h      Show this message.

EOF
    exit 1
}

function _exit () {
    echo "Error: $1";
    echo "       Abort Elinks installation."
    exit 1
}

# Default values.
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"
elinks_download="https://raw.githubusercontent.com/a1black/dotfiles/master/.elinks/elinks.conf"

# Process arguments.
while getopts ":hu:c:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        c) elinks_download="$OPTARG";;
        h) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $EUID -ne 0 && $cuser != $USER ]]; then
    _exit "Run script with root privileges."
fi

# Check if Elinks is already installed.
if elinks --version > /dev/null 2>&1; then
    _exit "Command-line browser Elinks is already installed."
fi

# Install Elinks.
echo "==> Install Elinks."
sudo apt-get install -qq elinks

# Elinks configuration directory.
mkdir -p /home/$cuser/.elinks

# Download `.elinks.conf` configuration file.
elinks_file="/home/$cuser/.elinks/elinks.conf"
if [ ! -f "$elinks_file" ]; then
    elinks_tmp=$(mktemp -q)
    echo "==> Download \`.elinks.conf\` configuration file."
    if curl --version > /dev/null 2>&1; then
        curl -fsLo $elinks_tmp $elinks_download
    else
        wget -qO - $elinks_download > $elinks_tmp
    fi
    if [ $? -ne 0 ]; then
        echo "Fail to download \`.elinks.conf\` file."
    else
        cp -f $elinks_tmp $elinks_file
        chown $cuser:$(id -gn $cuser) $elinks_file
    fi
    rm -f $elinks_tmp
fi

# Change owner of directories utilized by Elinks.
sudo chown -R $cuser:$(id -gn $cuser) /home/$cuser/.elinks
