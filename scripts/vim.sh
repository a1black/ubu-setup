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
    -h      Show this message.

EOF
    exit 1
}

function _exit () {
    echo "Error: $1";
    echo "       Abort Vim installation."
    exit 1
}

# Default values.
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"
vimrc_download="https://raw.githubusercontent.com/a1black/dotfiles/master/.vimrc"

# Process arguments.
while getopts ":hu:c:p:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        c) vimrc_download="$OPTARG";;
        p) vim_plug="${OPTARG,,}";;
        h) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $EUID -ne 0 && $cuser != $USER ]]; then
    _exit "Run script with root privileges."
fi

# Delete old version of Vim if installed.
vim --version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    VIM_VERSION=$(vim --version | grep --color=never -oP "(?<=IMproved )\d+")
    if [ $VIM_VERSION -ge 8 ]; then
        _exit "Vim is already installed."
    else
        sudo apt-get purge -qq vim
    fi
fi

# Get Vim version in system native repository.
VIM_VERSION=$(apt-cache show vim | sed -n '/^Version:/{s/\w\+:\s*//g p}' | \
    head -n 1 | grep --color=never -o "^[0-9]\+")

if [ $VIM_VERSION -lt 8 ]; then
    echo "==> Add unofficial Vim PPA repository."
    sudo add-apt-repository -y ppa:jonathonf/vim
    sudo apt-get update -qq
fi

echo "==> Install text editor Vim."
sudo apt-get install -qq vim

# Check if curl is installed.
curl --version > /dev/null 2>&1
HAS_CURL=$?

# Download `.vimrc` configuration file.
vimrc_file="/home/$cuser/.vimrc"
if [ ! -f "$vimrc_file" ]; then
    vimrc_tmp=$(mktemp -q)
    echo "==> Download \`.vimrc\` dotfile."
    if [ $HAS_CURL -eq 0 ]; then
        curl -fsLo $vimrc_tmp $vimrc_download
    else
        wget -qO - $vimrc_download > $vimrc_tmp
    fi
    if [ $? -ne 0 ]; then
        echo "Fail to download \`.vimrc\` file."
    else
        cp -f $vimrc_tmp $vimrc_file
        chown $cuser:$(id -gn $cuser) $vimrc_file
    fi
    rm -f $vimrc_tmp
fi

# Directories needed for Vim.
mkdir -p /home/$cuser/.vim/{autoload,backups,session,swap,undo}

if [ "$vim_plug" = "vundle" ]; then
    echo "==> Install Vundle plugin manager."
    vim_plug_url="https://github.com/VundleVim/Vundle.vim.git"
    git clone -q --depth 1 $vim_plug_url /home/$cuser/.vim/bundle/Vundle.vim
    vim_plug_cmd="PluginInstall"
elif [ "$vim_plug" = "pathogen" ]; then
    echo "==> Install Pathogen plugin manager."
    vim_plug_url="https://raw.githubusercontent.com/tpope/vim-pathogen/master/autoload/pathogen.vim"
    if [ $HAS_CURL -eq 1 ]; then
        curl -fsLo /home/$cuser/.vim/autoload/pathogen.vim $vim_plug_url
    else
        wget -qO - $vim_plug_url > /home/$cuser/.vim/autoload/pathogen.vim
    fi
else
    echo "==> Install Plug.Vim plugin manager."
    vim_plug_url=https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    if [ $HAS_CURL -eq 0 ]; then
        curl -fsLo /home/$cuser/.vim/autoload/plug.vim $vim_plug_url
    else
        wget -qO - $vim_plug_url > /home/$cuser/.vim/autoload/plug.vim
    fi
    vim_plug_cmd="PlugInstall"
fi

# Change owner of directories utilized by Vim.
sudo chown -R ${cuser}:$(id -gn $cuser) /home/$cuser/.vim

# Install plugins defined in `.vimrc` file.
if [[ -f "/home/$cuser/.vimrc" && -n "$vim_plug_cmd" ]]; then
    sudo su - $cuser -c 'vim +$vim_plug_cmd +qall'
fi
