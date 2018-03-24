#!/usr/bin/env bash
# Install command-line web browser Elinks.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install command-line web browser Elinks.
OPTION:
    -u      Configure Elinks for provided user (default current user).
    -c      Download link for Elinks configuration file.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Elinks installation.'
    exit ${2:-1}
}

# Download Elinks configuration file and put it into user home directory.
# Args:
#   $1  User name.
#   $2  Link for downloading config file.
function download_config() {
    [[ $cuser = 'root' || -z "$2" ]] && return 1
    echo "==> Download '.elinks.conf' configuration file."
    local elinks_tmp=$(mktemp -q)
    local elinks_file=/home/$1/.elinks/elinks.conf
    wget -qO - $2 > $elinks_tmp 2> /dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Fail to download '.elinks.conf' file."
        return 1
    fi
    mkdir -p $(dirname $elinks_file) 2> /dev/null
    if [ $? -ne 0 ]; then
        echo 'Error: Fail to create Elinks config directory.'
        return 1
    fi
    mv -f $elinks_tmp $elinks_file
    chown -R $1:$(id -gn $1) $(dirname $elinks_file)
    chmod 644 $elinks_file
    return 0
}

# Default values.
#elinks_download=https://raw.githubusercontent.com/a1black/dotfiles/master/.elinks/elinks.conf

# Process arguments.
while getopts ":hu:c:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user '$OPTARG'.";;
        c) elinks_download="$OPTARG";;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126
[ "$cuser" = 'root' ] && _exit 'Can not install Elinks config file for root.' 126

# Determine user.
[ -z "$cuser" ] && { [ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER; }

# Check if Elinks is already installed.
if elinks --version > /dev/null 2>&1; then
    download_config "$cuser" "$elinks_download"
    _exit 'Command-line browser Elinks is already installed.'
fi

# Install Elinks.
echo '==> Install Elinks.'
sudo apt-get install -qq elinks

# Install config file.
download_config "$cuser" "$elinks_download"
