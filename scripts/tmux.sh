#!/usr/bin/env bash
# Install terminal multiplexer Tmux.

function show_usage() {
    cat << EOF
Usage: sudo $(basename $0) [OPTION]
Install terminal multiplexer Tmux.
OPTION:
    -u      User who will recieve Tmux configuration files.
    -g      Tmux.conf download link.
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
    echo "       Abort Tmux installation."
    exit 1
}

# Check if Tmux version is an old one.
function check_version() {
    local major=$(echo "$1" | cut -d '.' -f 1)
    local minor=$(echo "$1" | cut -d '.' -f 2)
    if [[ $major -lt 2 || $minor -lt 4 ]]; then
        return 1
    fi
    return 0
}

# Default values.
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"
tmux_download="https://raw.githubusercontent.com/a1black/dotfiles/master/.tmux.conf"

# Process arguments.
while getopts ":hDu:g:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        g) tmux_download="$OPTARG";;
        D) UBU_SETUP_DRY=1;;
        h) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $EUID -ne 0 && $cuser != $USER ]]; then
    _exit "Run script with root privileges."
fi

# Delete old version of Tmux if installed.
tmux -V > /dev/null 2>&1
if [ $? -eq 0 ]; then
    TMUX_VERSION=$(tmux -V | cut -d ' ' -f 2)
    if check_version "$TMUX_VERSION"; then
        _exit "Tmux is already installed."
    else
        echo "==> Delete old version of Tmux."
        _eval "sudo apt-get purge -qq tmux"
    fi
fi

# get Tmux version in native system repository.
TMUX_VERSION=$(apt-cache show tmux | sed -n '/^Version:/{s/\w\+:\s*//g p}' | \
    head -n 1 | grep --color=never -o '^[0-9]\+\.[0-9]\+')

# Install and configure Tmux.
if check_version "$TMUX_VERSION"; then
    echo "==> Install Tmux."
    _eval "sudo apt-get install -qq tmux"
elif git --version > /dev/null 2>&1; then
    echo "==> Build from source code."
    if apt-cache show libncurses6 > /dev/null 2>&1; then
        ncurses=libncurses6-dev
    else
        ncurses=libncurses5-dev
    fi
    _eval "sudo apt-get install -qq build-essential pkg-config \
automake libevent-dev $ncurses"
    tmux_tmp=$(mktemp -dq)
    _eval "git clone -q https://github.com/tmux/tmux.git $tmux_tmp"
    cd $tmux_tmp
    tmux_latest=$(git rev-list --tags --max-count=1 | xargs git describe --tags)
    _eval "git checkout --quiet $tmux_latest"
    _eval "sh autogen.sh"
    _eval "$tmux_tmp/configure && make --quiet"
    _eval "sudo make --quiet install"
    cd - > /dev/null
    rm -rf $tmux_tmp
else
    _exit "Git is required to install latest Tmux version."
fi

# Download Tmux configuration file.
tmux_file="/home/$cuser/.tmux.conf"
if [ ! -f "$tmux_file" ]; then
    tmux_tmp=$(mktemp -q)
    echo "==> Download \`.tmux.conf\` dotfile."
    if curl --version > /dev/null 2>&1; then
        _eval "curl -fsLo $tmux_tmp $tmux_download"
    else
        _eval "wget -qO - $tmux_download > $tmux_tmp"
    fi
    if [ $? -ne 0 ]; then
        echo "Fail to download \`.tmux.conf\` file."
    else
        _eval "cp -f $tmux_tmp $tmux_file"
        _eval "chown $cuser:$(id -gn $cuser) $tmux_file"
    fi
    rm -f $tmux_tmp
fi

# Directory needed for Tmux configuration.
_eval "mkdir -p /home/$cuser/.tmux"

# Install Tmux plugin manager.
if git --version > /dev/null 2>&1; then
    _eval "git clone -q --depth 1 https://github.com/tmux-plugins/tpm \
/home/$cuser/.tmux/plugins/tpm"
fi

# Change owner of `.tmux` directory.
_eval "sudo chown -R ${cuser}:$(id -ng $cuser) /home/$cuser/.tmux"
