#!/usr/bin/env bash
# Install terminal multiplexer Tmux.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest available version of terminal multiplexer Tmux.
OPTION:
    -u      Install locally for specified user.
    -c      Download link for tmux configuration file.
    -n      Install from system native repository.
    -d      Delete Tmux if installed.
    -h      Show this message.

EOF
    exit 1
}

function _exit () {
    echo "Error: $1";
    echo "       Abort Tmux installation."
    exit 1
}

# Check if Tmux version is an old one.
function is_version_too_old() {
    local major=$(echo "$1" | cut -d '.' -f 1)
    local minor=$(echo "$1" | cut -d '.' -f 2)
    if [[ $major -lt 2 || $minor -lt 4 ]]; then
        return 0
    fi
    return 1
}

# Delete Tmux binary files.
function delete_bin() {
    sudo find $1 -regextype sed -type f -executable -regex '^.\+/bin/tmux$' -delete
    sudo find $1 -regextype sed -type f -regex '^.\+/man/man[0-9]/tmux\.[0-9]$' -delete
    return $?
}

# Uninstall Tmux from the system.
# Args:
#   $1 - Delete locaty installed package.
function uninstall_tmux() {
    echo "==> Delete currently installed package."
    if [ "$1" = 'root' ]; then
        sudo apt-get purge -qq tmux byobu
        delete_bin "/usr /home"
    else
        delete_bin "/home/$1"
    fi
}

# Default values.
cuser='root'
tmux_native_install=1
tmux_uninstall=1
tmux_download="https://raw.githubusercontent.com/a1black/dotfiles/master/.tmux.conf"

# Process arguments.
while getopts ":hndu:c:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        c) tmux_download="$OPTARG";;
        n) tmux_native_install=0;;
        d) tmux_uninstall=0;;
        h) show_usage;;
    esac
done

if [[ $EUID -ne 0 && "$cuser" = 'root' ]]; then
    cuser=$USER
fi
[ "$cuser" = 'root' ] && tmux_location=/usr/local || tmux_location=/home/$cuser/.local

# Check arguments.
if [[ $tmux_uninstall -eq 0 && $tmux_native_install -eq 0 ]]; then
    _exit "Ambiguous use of script options."
elif [[ $EUID -ne 0 && $cuser != $USER ]]; then
    _exit "Run script with root privileges or provide user to run locally."
fi

# Get currently installed Tmux version.
tmux_current=$(tmux -V 2> /dev/null | cut -d ' ' -f 2)

# Check Tmux version in system native repository.
if [ $tmux_native_install -eq 0 ]; then
    sudo apt-get update -qq
    tmux_apt=$(apt-cache show tmux | sed -n '/^Version:/{s/\w\+:\s*//g p}' | \
        head -n 1 | grep --color=never -o '^[0-9]\+\.[0-9]\+')
    if [[ "$tmux_current" = "$tmux_apt" ]]; then
        _exit "Tmux is already installed."
    elif is_version_too_old "$tmux_apt"; then
        _exit "System repository has an old version of Tmux."
    fi
fi

# Delete currently installed package.
uninstall_tmux "$cuser"
[ $tmux_uninstall -eq 0 ] && exit 0

# Install Tmux from system APT repository.
if [ $tmux_native_install -eq 0 ]; then
    echo "==> Install Tmux from system APT repository."
    sudo apt-get install -qq tmux
elif git --version > /dev/null 2>&1; then
    if [ ! -d "$tmux_location" ]; then
        mkdir -p $tmux_location 2> /dev/null
        [ $? -ne 0 ] && _exit "Fail to create directory for hosting Tmux binary."
        chown $cuser:$(id -gn $cuser) $tmux_location
    fi
    # Install dependencies.
    echo "==> Build Tmux from source code."
    sudo apt-get update -qq
    ncurses=libncurses5-dev
    apt-cache show libncurses6 > /dev/null 2>&1 && ncurses=libncurses6-dev
    sudo apt-get install -qq build-essential pkg-config automake libevent-dev "$ncurses"
    # Clone source code from github.
    tmux_tmp=$(mktemp -dq)
    git clone -q https://github.com/tmux/tmux.git $tmux_tmp
    cd $tmux_tmp
    # Checkout latest tag.
    tmux_latest=$(git rev-list --tags --max-count=1 | xargs git describe --tags)
    git checkout --quiet $tmux_latest
    # Build and install.
    sh autogen.sh
    ./configure --prefix=$tmux_location
    make --quiet
    make install
    if [[ "$cuser" != 'root' ]]; then
        chown $cuser:$(id -gn $cuser) $tmux_location/bin/tmux
        chown $cuser:$(id -gn $cuser) $tmux_location/share/man/man*/tmux*
    fi

    # Clean-up.
    cd - > /dev/null
    rm -rf $tmux_tmp
else
    _exit "Git is required for Tmux installation."
fi

# Download Tmux configuration file.
tmux_conf="/home/$cuser/.tmux.conf"
if [[ "$cuser" != 'root' && ! -f "$tmux_conf" && -n "$tmux_download" ]]; then
    echo "==> Download \`.tmux.conf\` configuration file."
    tmux_tmp=$(mktemp -q)
    wget -qO - $tmux_download > $tmux_tmp
    if [ $? -ne 0 ]; then
        echo "Fail to download \`.tmux.conf\` file."
    else
        mv -f $tmux_tmp $tmux_conf
        chown $cuser:$(id -gn $cuser) $tmux_conf
    fi
    rm -f $tmux_tmp
fi

# Configure Tmux.
tmux_directory=/home/$cuser/.tmux
if [[ "$cuser" != 'root' && ! -e "$tmux_directory" ]]; then
    # Directory needed for Tmux configuration.
    mkdir -p $tmux_directory
    # Install Tmux plugin manager.
    if git --version > /dev/null 2>&1; then
        git clone -q --depth 1 https://github.com/tmux-plugins/tpm $tmux_directory/plugins/tpm
    fi
    # Change owner of `.tmux` directory.
    chown -R $cuser:$(id -gn $cuser) $tmux_directory
fi
