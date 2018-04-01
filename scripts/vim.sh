#!/usr/bin/env bash
# Install text editor Vim.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install text editor Vim and plugin manager.
OPTION:
    -u      Configure Vim for provided user (default current user).
    -c      Download link for Vim configuration file.
    -p      Vim plugin manager (plug, pathogen, vundle).
    -f      Force removal of an old version of Vim.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Vim installation.'
    exit ${2:-1}
}

# Set file owner.
# Args:
#   -R  Recursive flag.
#   $1  User name.
#   $2  Path.
function _chown() {
    local rec=''
    if [ "$1" = '-R' ]; then
        rec='-R'
        shift
    fi
    bash -c "chown $rec $1:$(id -gn $1) $2 2> /dev/null"
}

# Check if vim major version is an old one.
function check_vim_version() {
    [ $(($1)) -ge 8 ]
}

# Configure Vim.
# Args:
#   $1  User name.
function configure_vim() {
    [[ -z "$1" || "$1" = 'root' ]] && return 1
    # Directories needed for Vim.
    mkdir -p /home/$1/.vim/{autoload,backups,session,swaps,undo} 2> /dev/null
    [ $? -ne 0 ] && return 1
    # Change owner of download data.
    _chown -R $1 /home/$1/.vim
}

# Download vimrc configuration file.
# Args:
#   $1  User name.
#   $2  Download link.
function download_config() {
    [[ -z "$1" || -z "$2" || "$1" = 'root' ]] && return 1
    echo '==> Download Vim configuration file.'
    local vimrc_file=/home/$1/.vimrc
    local vimrc_tmp=$(mktemp -q)
    wget -qO - $2 > $vimrc_tmp 2> /dev/null
    if [ $? -eq 0 ]; then
        mv -f $vimrc_tmp $vimrc_file
        _chown $1 $vimrc_file
        chmod 644 $vimrc_file
    fi
}

# Install Vim plugin manager.
# Args:
#   $1  User name.
#   $2  Plugin name.
function install_plugin_manager() {
    [[ -z "$1" || -z "$2" || "$1" = 'root' ]] && return 1
    echo '==> Install Vim plugin manager.'
    mkdir -p /home/$1/.vim/autoload 2> /dev/null
    local vim_plug_cmd=''
    if [ "$2" = 'vundle' ]; then
        vim_plug_cmd='PluginInstall'
        git clone -q --depth 1 "https://github.com/VundleVim/Vundle.vim.git" \
            /home/$1/.vim/bundle/Vundle.vim > /dev/null 2>&1
    elif [ "$2" = 'pathogen' ]; then
        wget -qO - "https://raw.githubusercontent.com/tpope/vim-pathogen/master/autoload/pathogen.vim" > /home/$1/.vim/autoload/pathogen.vim 2> /dev/null
    elif [ "$2" = 'plug' ]; then
        vim_plug_cmd='PlugInstall'
        wget -qO - "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" > /home/$1/.vim/autoload/plug.vim 2> /dev/null
    else
        [ 1 -eq 0 ]
    fi
    local has_error=$?
    _chown -R $1 /home/$1/.vim
    if [ $has_error -ne 0 ]; then
        echo "Error: Fail to install '$2' plugin manager."
        return 1
    fi
    # Install plugins defined in ".vimrc" file.
    git --version > /dev/null 2>&1
    if [[ $? -eq 0 && -n "$vim_plug_cmd" && -f /home/$1/.vimrc ]]; then
        sudo -iH -u $1 bash -c "vim +$vim_plug_cmd +qall"
    fi
}

# Default values.
#vimrc_download=https://raw.githubusercontent.com/a1black/dotfiles/master/.vimrc

# Process arguments.
while getopts ":hfu:c:p:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user '$OPTARG'.";;
        c) vimrc_download="$OPTARG";;
        p) vim_plug="${OPTARG,,}";;
        f) vim_force_remove=0;;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126
[ "$cuser" = 'root' ] && _exit 'Can not configure Vim for root user.' 126

# Determine user.
[ -z "$cuser" ] && { [ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER; }

# Delete old version of Vim if installed.
current_major_ver=$(vim --version 2> /dev/null | head -n 1 | \
    grep --color=never -oP '(?<=IMproved )\d+')
if [ $? -eq 0 ]; then
    check_vim_version "$current_major_ver"
    if [[ $? -ne 0 && -n "$vim_force_remove" ]]; then
        echo '==> Delete older version of Vim.'
        sudo apt-get purge -qq vim vim-common vim-runtime vim-tiny
    else
        configure_vim $cuser
        download_config $cuser $vimrc_download
        install_plugin_manager $cuser $vim_plug
        _exit 'Vim is already installed.'
    fi
fi

# Get Vim version in system native repository.
repo_major_ver=$(apt-cache show vim 2> /dev/null | \
    sed -n '/^Version:/{s/\w\+:\s*//g p}' | \
    head -n 1 | grep --color=never -o '^[0-9]\+')
if ! check_vim_version "$repo_major_ver"; then
    echo '==> Add unofficial Vim PPA repository.'
    sudo add-apt-repository -y ppa:jonathonf/vim
    sudo apt-get update -qq
fi

echo '==> Install text editor Vim.'
sudo apt-get install -qq vim

# Configure vim.
configure_vim $cuser
download_config $cuser $vimrc_download
install_plugin_manager $cuser $vim_plug
