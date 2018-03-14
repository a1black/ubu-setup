#!/usr/bin/env bash
# Install statusline plugin written in python.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install status line plugin Powerline for current user.
OPTION:
    -u      User for whom Powerline will be installed.
    -h      Show this message.

EOF
    exit 1
}

function _exit () {
    echo "Error: $1";
    echo "       Abort Powerline plugin installation."
    exit 1
}

# Get available python version.
function get_python_version() {
    for py_version in ${PYTHON_VERSIONS[@]}; do
        if python$py_version -V > /dev/null 2>&1; then
            python$py_version -c "import sys; print(sys.version_info[0])" 2> /dev/null
            return 0
        fi
    done
    return 127
}

# Get powerline module installation path for provided python version.
function get_python_module_path() {
    python$1 -m pip show powerline-status | grep --color=never -oP '(?<=^Location: ).*'
    return $?
}

# Install/update powerline module and dependencies.
# Args:
#   $1  Python version.
#   $2  User name.
#   $3  Upgrade flag.
function install_update_powerline() {
    [ "$3" = 'upgrade' ] && upgrade_flag='--upgrade' || upgrade_flag=''
    if [ "$2" = 'root' ]; then
        sudo python$1 -m pip instal -qq $upgrade_flag psutil netifaces powerline-status powerline-gitstatus
    else
        sudo su - $2 -c "python$1 -m pip install --user -qq $upgrade_flag psutil netifaces powerline-status powerline-gitstatus"
    fi
    return $?
}

# Create symbol link to directory that contains plugins to bash/tmux/etc.
# Symlink is made to speed up Powerline.
function create_symlink() {
    if [[ -z "$1" || -z "$2" || "$2" = 'root' ]]; then
        exit 1
    fi
    local symlink=/home/$2/.local/lib/powerline-plugins
    if [ ! -e $(dirname $symlink) ]; then
        mkdir -p $(dirname $symlink)
        chown $cuser:$(id -gn $cuser) $(dirname $symlink)
    fi
    ln -fns $1/powerline/bindings $symlink 2> /dev/null
    if [ $? -ne 0 ]; then
        rm -f $symlink 2> /dev/null
        return 1
    fi
    chown $cuser:$(id -gn $cuser) $symlink
    return 0
}

# Default and global values.
PYTHON_VERSIONS=(3 2)
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"

# Process arguments.
while getopts ":hu:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        h) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $EUID -ne 0 && $cuser != $USER ]]; then
    _exit "Run script with root privileges."
fi

# Available python version.
pyv=$(get_python_version)
python$pyv -m pip --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    _exit "Python and PIP are required for Powerline installation."
fi

# Check if Powerline plugin is already installed.
if powerline -h > /dev/null 2>&1 || [ -x /home/$cuser/.local/bin/powerline ]; then
    echo "==> Update Powerline python module."
    for py_version in ${PYTHON_VERSIONS[@]}; do
        module_path=$(get_python_module_path $py_version)
        [ $? -ne 0 ] && continue
        if [[ "$module_path" =~ /home/$cuser/.local ]]; then
            install_update_powerline $py_version $cuser 'upgrade'
            create_symlink "$module_path" "$cuser"
        else
            install_update_powerline $py_version 'root' 'upgrade'
        fi
    done
    exit 0
fi

# Install dependencies and powerline python module.
echo "==> Install statusline plugin Powerline."
#sudo apt-get install -qq libgit2-[0-9]
#sudo apt-get install -qq python-pygit2
install_update_powerline $pyv $cuser
if [ $? -ne 0 ]; then
    exit 1
else
    module_path=$(get_python_module_path $pyv)
    create_symlink "$module_path" "$cuser"
fi

# Check if curl is installed
curl --version > /dev/null 2>&1
HAS_CURL=$?

# Install powerline fonts.
echo "==> Download and install powerline fonts."
if [[ "$cuser" = 'root' ]]; then
    fontdir=/usr/local/share/fonts
    fontconfdir=/usr/share/fontconfig/conf.avail/
else
    fontdir="/home/$cuser/.local/share/fonts"
    fontconfdir="/home/$cuser/.config/fontconfig/conf.d"
fi
symbols_github="https://github.com/powerline/powerline/raw/develop/font"
fonts_github="https://github.com/powerline/fonts/raw/master"

mkdir -p $fontdir $fontconfdir
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
    if [ $HAS_CURL -eq 0 ]; then
        curl -sfLo "$fontdir/$fontfile" "${fonts[$i]}"
    else
        wget -qO - "${fonts[$i]}" > "$fontdir/$fontfile"
    fi
done
for ((i=0; i<${#fconfigs[@]}; i++)); do
    fconffile=$(basename "${fconfigs[$i]}")
    if [ $HAS_CURL -eq 0 ]; then
        curl -sfLo "$fontconfdir/$fconffile" "${fconfigs[$i]}"
    else
        wget -qO - "${fconfigs[$i]}" > "$fontconfdir/$fconffile"
    fi
done

# Change owner of font directory.
chown -R $cuser:$(id -gn $cuser) $fontdir $fontconfdir

# Update font cache.
if fc-cache --version > /dev/null 2>&1; then
    sudo fc-cache -vf $fontdir
fi
