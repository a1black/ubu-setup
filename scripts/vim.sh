#!/usr/bin/env bash
# Install text editor Vim.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install text editor Vim and plugin manager.
OPTION:
    -u      User who will recieve Vim configuration files.
    -g      Vimrc download link.
    -p      Vim plugin manager (plug, pathogen, vundle).
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
    echo "       Abort Vim installation."
    exit 1
}

# Default values.
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"
vimrc_download="https://raw.githubusercontent.com/a1black/dotfiles/master/.vimrc"

# Process arguments.
while getopts ":hDu:g:p:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        g) vimrc_download="$OPTARG";;
        p) vim_plug="${OPTARG,,}";;
        D) UBU_SETUP_DRY=1;;
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
        _eval "sudo apt-get purge -qq vim"
    fi
fi

# Get Vim version in system native repository.
VIM_VERSION=$(apt-cache show vim | sed -n '/^Version:/{s/\w\+:\s*//g p}' | \
    head -n 1 | grep --color=never -o "^[0-9]\+")

if [ $VIM_VERSION -lt 8 ]; then
    echo "==> Add unofficial Vim PPA repository."
    _eval "sudo add-apt-repository -y ppa:jonathonf/vim"
    _eval "sudo apt-get update -qq"
fi

echo "==> Install text editor Vim."
_eval "sudo apt-get install -qq vim"

# Check if curl is installed.
curl --version > /dev/null 2>&1
HAS_CURL=$?

# Download `.vimrc` configuration file.
vimrc_file="/home/$cuser/.vimrc"
if [ ! -f "$vimrc_file" ]; then
    vimrc_tmp=$(mktemp -q)
    echo "==> Download \`.vimrc\` dotfile."
    if [ $HAS_CURL -eq 0 ]; then
        _eval "curl -fsLo $vimrc_tmp $vimrc_download"
    else
        _eval "wget -qO - $vimrc_download > $vimrc_tmp"
    fi
    if [ $? -ne 0 ]; then
        echo "Fail to download \`.vimrc\` file."
    else
        _eval "cp -f $vimrc_tmp $vimrc_file"
        _eval "chown $cuser:$(id -gn $cuser) $vimrc_file"
    fi
    rm -f $vimrc_tmp
fi

# Directories needed for Vim.
_eval "mkdir -p /home/$cuser/.vim/{autoload,backups,session,swap,undo}"

if [ "$vim_plug" = "vundle" ]; then
    echo "==> Install Vundle plugin manager."
    vim_plug_url="https://github.com/VundleVim/Vundle.vim.git"
    _eval "git clone -q --depth 1 $vim_plug_url /home/$cuser/.vim/bundle/Vundle.vim"
    vim_plug_cmd="PluginInstall"
elif [ "$vim_plug" = "pathogen" ]; then
    echo "==> Install Pathogen plugin manager."
    vim_plug_url="https://raw.githubusercontent.com/tpope/vim-pathogen/master/autoload/pathogen.vim"
    if [ $HAS_CURL -eq 1 ]; then
        _eval "curl -fsLo /home/$cuser/.vim/autoload/pathogen.vim $vim_plug_url"
    else
        _eval "wget -qO - $vim_plug_url > /home/$cuser/.vim/autoload/pathogen.vim"
    fi
else
    echo "==> Install Plug.Vim plugin manager."
    vim_plug_url=https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    if [ $HAS_CURL -eq 0 ]; then
        _eval "curl -fsLo /home/$cuser/.vim/autoload/plug.vim $vim_plug_url"
    else
        _eval "wget -qO - $vim_plug_url > /home/$cuser/.vim/autoload/plug.vim"
    fi
    vim_plug_cmd="PlugInstall"
fi

# Change owner of directories utilized by Vim.
_eval "sudo chown -R ${cuser}:$(id -gn $cuser) /home/$cuser/.vim"

# Install plugins defined in `.vimrc` file.
if [[ -f "/home/$cuser/.vimrc" && -n "$vim_plug_cmd" ]]; then
    _eval "sudo su - $cuser -c 'vim +$vim_plug_cmd +qall'"
fi
