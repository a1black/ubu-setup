#!/usr/bin/env bash
# Install powerline fonts and symbols.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install fonts for powerline plugins.
OPTION:
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Powerline fonts installation.'
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

# Default and global values.
[ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER

# Process arguments.
while getopts ":h" OPTION; do
    case $OPTION in
        *) show_usage;;
    esac
done

# Check effective user privileges.
[ $cuser = 'root' ] && _exit 'Can not install fonts for root user.' 126

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
