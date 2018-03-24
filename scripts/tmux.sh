#!/usr/bin/env bash
# Install terminal multiplexer Tmux.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest available version of terminal multiplexer Tmux.
OPTION:
    -l      Perform operation localy.
    -c      Download link for Tmux configuration file.
    -n      Install from system native repository.
    -d      Delete Tmux if installed.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Tmux installation.'
    exit ${2:-1}
}

# Execute command as user.
# Args:
#   $1  User name.
#   $2  Command.
function _eval() {
    if [ $UID -eq 0 ]; then
        sudo -iH -u $1 bash -c "$2"
    else
        bash -c "$2"
    fi
}

# Create directory.
# Args:
#   $1  User name.
#   $2  Path.
function _mkdir() {
    _eval $1 "mkdir -p $2 2> /dev/null"
    [ $? -ne 0 ] && return 1
    _chown -R "$1" "$2"
}

# Change the owner and group for provided file.
# Args:
#   -R  Optional flag for recursive operation.
#   $1  Owner name.
#   $2  Path to file.
function _chown() {
    local rec=''
    if [ "$1" = '-R' ]; then
        rec='-R'
        shift
    fi
    bash -c "chown --quiet -h $rec $1:$(id -gn $1) $2"
    return $?
}

# Make shure that version is not old.
# Args:
#   $1  Tmux version.
function check_tmux_version() {
    local major=$(echo "$1" | cut -d '.' -f 1)
    local minor=$(echo "$1" | cut -d '.' -f 2)
    ! [[ $((major)) -lt 2 || $((minor)) -lt 4 ]]
}

# Get version of installed Tmux.
# Args:
#   $1  User name.
function get_tmux_version() {
    _eval "$1" 'tmux -V 2> /dev/null' | awk '{print $2}'
}

# Delete Tmux binary files.
# Args:
#   $1  Base path for search.
function delete_bin() {
    sudo find $1 -type f -executable -regex ^.\+/bin/tmux$ -delete
    sudo find $1 -type f -regex ^.\+/man/man[0-9]/tmux\.[0-9]$ -delete
}

# Configure Tmux.
# Args:
#   $1  User name.
#   $2  Download link.
function download_config() {
    [[ -z "$1" || -z "$2" || "$1" = 'root' ]] && return 1
    echo '==> Download .tmux.conf configuration file.'
    local tmux_tmp=$(mktemp -q)
    local tmux_conf=/home/$1/.tmux.conf
    wget -qO - $2 > $tmux_tmp 2> /dev/null
    if [ $? -eq 0 ]; then
        mv -f $tmux_tmp $tmux_conf
        _chown $cuser $tmux_conf
        chmod 664 $tmux_conf
    fi
}

# Install Tmux plugin manager.
# Args:
#   $1  User name.
function install_plugin_manager() {
    [[ -z "$1" || "$1" = 'root' ]] && return 1
    echo '==> Install Tmux plugin manager.'
    tmux_directory=/home/$cuser/.tmux
    git clone -q --depth 1 https://github.com/tmux-plugins/tpm \
        /home/$1/.tmux/plugins/tpm > /dev/null 2>&1
    _chown -R $1 /home/$1/.tmux
}

# Default values.
[ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER
tmux_do_local=1
tmux_native=1
tmux_uninstall=1
#tmux_download=https://raw.githubusercontent.com/a1black/dotfiles/master/.tmux.conf

# Process arguments.
while getopts ":hndlc:" OPTION; do
    case $OPTION in
        c) tmux_download="$OPTARG";;
        l) tmux_do_local=0;;
        n) tmux_native=0;;
        d) tmux_uninstall=0;;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126
[[ $tmux_do_local -eq 0 && $cuser = 'root' ]] && _exit 'Can not install Tmux for root user.' 126

# Check arguments.
if [[ $tmux_native -eq 0 && $tmux_do_local -eq 0 ]]; then
    _exit 'Can not install Tmux locally from system repository.' 2
elif [[ $tmux_uninstall -eq 0 && $tmux_native -eq 0 ]]; then
    _exit 'Ambiguous use of script options.' 2
fi

# Determine path for placing Tmux binaries.
tmux_location=/usr/local
[ $tmux_do_local -eq 0 ] && tmux_location=/home/$cuser/.local

# Uninstall Tmux.
if [ $tmux_uninstall -eq 0 ]; then
    echo '==> Uninstall Tmux.'
    if [ $tmux_do_local -eq 0 ]; then
        delete_bin $tmux_location
    else
        sudo apt-get purge -qq tmux byobu
        delete_bin $tmux_location
        delete_bin '/home'
    fi
    exit 0
fi

# Install Tmux from system native repository.
if [ $tmux_native -eq 0 ]; then
    tmux -V > /dev/null 2>&1 && _exit 'Tmux is already installed.'
    echo '==> Install Tmux from system repository.'
    sudo apt-get update -qq
    sudo apt-get install -qq tmux
    tmux_current_ver=$(get_tmux_version $cuser)
    [ -z "$tmux_current_ver" ] && _exit 'Installation failed.'
    check_tmux_version "$tmux_current_ver" || echo 'Tmux version is old.'
    download_config $cuser $tmux_download
    install_plugin_manager $cuser
    exit 0
fi

# Check required software.
git --version > /dev/null 2>&1 || _exit 'Git is not available.'

# Create all required directories.
if [ $tmux_do_local -eq 0 ]; then
    _mkdir $cuser $tmux_location/bin || _exit 'Fail to create directory for Tmux binary.'
    _mkdir $cuser $tmux_location/share/man/man1
fi

# Install tools for building Tmux from source code.
echo '==> Install dependencies.'
sudo apt-get update -qq
ncurses=libncurses5-dev
apt-cache show libncurses6-dev > /dev/null 2>&1 && ncurses=libncurses6-dev
sudo apt-get install -qq build-essential pkg-config automake libevent-dev $ncurses

# Download Tmux source code.
echo '==> Download source code.'
tmux_tmp=$(mktemp -dq)
git clone -q https://github.com/tmux/tmux.git $tmux_tmp 2> /dev/null
[ $? -ne 0 ] && _exit 'Fail to download Tmux source code.'
cd $tmux_tmp > /dev/null
tmux_latest=$(git rev-list --tags --max-count=1 | xargs git describe --tags)
git checkout --quiet $tmux_latest

# Install Tmux.
echo '==> Build Tmux from source code.'
sh autogen.sh
sed -i -e "s/VERSION='master'/VERSION='$tmux_latest'/g" \
    -e "s/PACKAGE_VERSION='master'/PACKAGE_VERSION='$tmux_latest'/g" \
    -e "s/PACKAGE_STRING='tmux master'/PACKAGE_STRING='tmux $tmux_latest'/g" configure
./configure --prefix=$tmux_location
make --quiet
make install
if [ $tmux_do_local -eq 0 ]; then
    _chown $cuser $tmux_location/bin/tmux
    _chown $cuser $tmux_location/share/man/man1/tmux*
fi
# Clean-up.
cd - > /dev/null
rm -rf $tmux_tmp

download_config $cuser $tmux_download
install_plugin_manager $cuser
