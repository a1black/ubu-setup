#!/usr/bin/env bash
# Install statusline plugin written in python.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install status line plugin Powerline for current user.
OPTION:
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Powerline plugin installation.'
    exit ${2:-1}
}

# Execute command as user.
#   $1  User name.
#   $2  Command.
function _eval() {
    [[ -z "$1" || -z "$2" ]] && return 1
    if [ $UID -eq 0 ]; then
        sudo -iH -u $1 bash -c "$2"
    else
        bash -c "$2"
    fi
}

# Get available python version.
# Args:
#   $1  List of versions.
function get_python_version() {
    for py_version in $1; do
        python$py_version -m pip --version > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo $py_version
            return 0
        fi
    done
    return 127
}

# Get powerline module installation path for provided python version.
# Args:
#   $1  Run as user.
#   $2  Python version 2 or 3.
function get_python_module_path() {
    _eval $1 "python$2 -m pip show powerline-status 2> /dev/null" | \
        grep --color=never -oP '(?<=^Location: ).*'
    return $?
}

# Install/update powerline module and dependencies.
# Args:
#   --upgrade
#   $1  User name.
#   $2  Python version 2 or 3.
function install_update_powerline() {
    local upgrade_flag=''
    if [ "$1" = '--upgrade' ]; then
        upgrade_flag=$1
        shift
    fi
    _eval $1 "python$2 -m pip install --user -qq $upgrade_flag psutil netifaces powerline-status powerline-gitstatus"
}

# Create symbol link to directory that contains plugins to bash/tmux/etc.
# Symlink is made to speed up Powerline.
# Args:
#   $1  User name.
#   $2  Python module installation path.
function create_symlink() {
    [[ -z "$1" || -z "$2" || "$1" = 'root' ]] && return 1
    local symlink=/home/$1/.local/lib/powerline-plugins
    local sym_parent=$(dirname $symlink)
    _eval $1 "mkdir -p $sym_parent 2> /dev/null"
    chown -R $1:$(id -gn $1) $sym_parent
    ln -fns $2/powerline/bindings $symlink 2> /dev/null
    chown -h $1:$(id -gn $1) $symlink 2> /dev/null
}

# Default and global values.
PYTHON_VERSIONS='3 2'
[ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER

# Process arguments.
while getopts ":h" OPTION; do
    case $OPTION in
        *) show_usage;;
    esac
done

# Check effective user privileges.
[ $cuser = 'root' ] && _exit 'Can not install Powerline for root user.' 126

# Available python version.
pyv=$(get_python_version "$PYTHON_VERSIONS")
if [ $? -ne 0 ]; then
    _exit 'Python and PIP are required for Powerline installation.' 127
fi

# Check if Powerline plugin is already installed.
_eval $cuser 'powerline -h > /dev/null 2>&1'
if [ $? -eq 0 ]; then
    echo '==> Update Powerline python module.'
    for py_version in "$PYTHON_VERSIONS"; do
        module_path=$(get_python_module_path $cuser $py_version)
        [ $? -ne 0 ] && continue
        install_update_powerline --upgrade $cuser $py_version
        create_symlink $cuser "$module_path"
    done
    exit 0
fi

# Install dependencies and powerline python module.
echo '==> Install statusline plugin Powerline.'
#sudo apt-get install -qq libgit2-[0-9]
#sudo apt-get install -qq python-pygit2
install_update_powerline $cuser $pyv
[ $? -ne 0 ] && _exit 'Fail to install dependencies.'
module_path=$(get_python_module_path $cuser $pyv)
create_symlink $cuser "$module_path"

# Install powerline fonts.
echo '==> Download and install powerline fonts.'
fontdir=/home/$cuser/.local/share/fonts
fontconfdir=/home/$cuser/.config/fontconfig/conf.d
symbols_github=https://github.com/powerline/powerline/raw/develop/font
fonts_github=https://github.com/powerline/fonts/raw/master

_eval $cuser "mkdir -p $fontdir $fontconfdir"
# Fonts.
fonts=("$symbols_github/PowerlineSymbols.otf" \
    "$fonts_github/AnonymousPro/Anonymice Powerline Bold Italic.ttf" \
    "$fonts_github/AnonymousPro/Anonymice Powerline Bold.ttf" \
    "$fonts_github/AnonymousPro/Anonymice Powerline Italic.ttf" \
    "$fonts_github/AnonymousPro/Anonymice Powerline.ttf" \
    "$fonts_github/FiraMono/FuraMono-Regular Powerline.otf" \
    "$fonts_github/FiraMono/FuraMono-Medium Powerline.otf")
fconfigs=("$symbols_github/10-powerline-symbols.conf")

# Download fonts.
for ((i=0; i<${#fonts[@]}; i++)); do
    fontfile=$(basename "${fonts[$i]}")
    wget -qO - "${fonts[$i]}" > "$fontdir/$fontfile" 2> /dev/null
done
for ((i=0; i<${#fconfigs[@]}; i++)); do
    fconffile=$(basename "${fconfigs[$i]}")
    wget -qO - "${fconfigs[$i]}" > "$fontconfdir/$fconffile" 2> /dev/null
done

# Change owner of font directory.
chown -R $cuser:$(id -gn $cuser) $fontdir $fontconfdir

# Update font cache.
if fc-cache --version > /dev/null 2>&1; then
    fc-cache -vf $fontdir
fi
