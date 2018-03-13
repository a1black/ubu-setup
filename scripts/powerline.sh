#!/usr/bin/env bash
# Install statusline plugin written in python.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install status line plugin Powerline.
OPTION:
    -u      User for whom Powerline will be installed.
    -D      Print commands, don't execute them.
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
    echo "       Abort Powerline plugin installation."
    exit 1
}

# Get available python version.
function py_version() {
    local version=$(python3 -c "import sys; print(sys.version_info[0])" 2> /dev/null)
    if [ $? -ne 0 ]; then
        version=$(python -c "import sys; print(sys.version_info[0])" 2> /dev/null)
        if [ $? -ne 0 ]; then
            return 127
        fi
    fi
    echo $(($version))
    return 0
}

# Default values.
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"

# Process arguments.
while getopts ":hDu:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        D) UBU_SETUP_DRY=1;;
        h) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $EUID -ne 0 && $cuser != $USER ]]; then
    _exit "Run script with root privileges."
fi

# Check if Powerline plugin is already installed.
which powerline > /dev/null 2>&1
if [ $? -eq 0 ]; then
    _exit "Powerline plugin is already installed."
fi

# Check if `python` is installed.
pyv=$(py_version)
if [[ $? -ne 0 || $pyv -eq 0 ]]; then
    _exit "Powerline plugin requires python."
fi

# Check if `pip` is installed.
pyv="python$pyv"
$pyv -m pip -V > /dev/null 2>&1
if [ $? -ne 0 ]; then
    _exit "Installer requires PIP module."
fi

# Install dependencies and powerline python module.
echo "==> Install statusline plugin Powerline."
#_eval "sudo apt-get install -qq libgit2-[0-9]"
#_eval "sudo apt-get install -qq $pyv-pygit2"
_eval "sudo su - $cuser -c '$pyv -m pip install --user -qq psutil netifaces powerline-status powerline-gitstatus'"

# Check if curl is installed
curl --version > /dev/null 2>&1
HAS_CURL=$?

# Install powerline fonts.
echo "==> Download and install powerline fonts."
fontdir="/home/$cuser/.local/share/fonts"
fontconfdir="/home/$cuser/.config/fontconfig/conf.d"
symbols_github="https://github.com/powerline/powerline/raw/develop/font"
fonts_github="https://github.com/powerline/fonts/raw/master"

_eval "mkdir -p $fontdir $fontconfdir"
# Fonts.
fonts=("${symbols_github}/PowerlineSymbols.otf" \
    "${fonts_github}/AnonymousPro/Anonymice Powerline Bold Italic.ttf" \
    "${fonts_github}/AnonymousPro/Anonymice Powerline Bold.ttf" \
    "${fonts_github}/AnonymousPro/Anonymice Powerline Italic.ttf" \
    "${fonts_github}/AnonymousPro/Anonymice Powerline.ttf" \
    "${fonts_github}/FiraMono/FuraMono-Regular Powerline.otf" \
    "${fonts_github}/FiraMono/FuraMono-Medium Powerline.otf")
fconfigs=("${symbols_github}/10-powerline-symbols.conf")

# Download fonts.
for ((i=0; i<${#fonts[@]}; i++)); do
    fontfile=$(basename "${fonts[$i]}")
    if [ $HAS_CURL -eq 0 ]; then
        _eval "curl -sfLo \"${fontdir}/${fontfile}\" --create-dir \"${fonts[$i]}\""
    else
        _eval "wget -qO - \"${fonts[$i]}\" > \"${fontdir}/${fontfile}\""
    fi
done
for ((i=0; i<${#fconfigs[@]}; i++)); do
    fconffile=$(basename "${fconfigs[$i]}")
    if [ $HAS_CURL -eq 0 ]; then
        _eval "curl -sfLo \"${fontconfdir}/${fconffile}\" --create-dir \"${fconfigs[$i]}\""
    else
        _eval "wget -qO - \"${fconfigs[$i]}\" > \"${fontconfdir}/${fconffile}\""
    fi
done

# Change owner of font directory.
_eval "sudo chown -R ${cuser}:$(id -gn $cuser) $fontdir $fontconfdir"

# Update font cache.
if which fc-cache > /dev/null 2>&1; then
    _eval "sudo fc-cache -vf $fontdir"
fi
