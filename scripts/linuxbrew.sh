#!/usr/bin/env bash
# Install package manager Linuxbrew.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install package manager Linuxbrew for current user.
Script will copy source code of Linuxbrew into '~/.local/share/linuxbrew'
and create symlink '~/.local/bin/brew' for Linuxbrew binary.
OPTION:
    -d      Delete Linuxbrew if installed.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Linuxbrew installation.'
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
    chown -R $1:$(id -gn $1) $2 2> /dev/null
}

# Default values.
[ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER
brew_uninstall=1

# Process arguments.
while getopts ":hd" OPTION; do
    case $OPTION in
        d) brew_uninstall=0;;
        *) show_usage;;
    esac
done

# Validate user.
[ $cuser = 'root' ] && _exit 'Can not [un]install Linuxbrew for root user.' 126
# Brew locations.
bin_location=/home/$cuser/.local/bin
man_location=/home/$cuser/.local/share/man/man1
brew_location=/home/$cuser/.local/share/linuxbrew

# Delete Linuxbrew source code.
if [ $brew_uninstall -eq 0 ]; then
    _eval $cuser 'brew --version > /dev/null 2>&1' || _exit 'Linuxbrew is not installed.' 127
    echo '==> Delete Linuxbrew.'
    brew_pkgs=$(_eval $cuser 'brew list 2> /dev/null')
    for pkg in $brew_pkgs; do
        _eval $cuser "brew rm -f --ignore-dependencies $pkg > /dev/null 2>&1"
    done
    rm -rf /home/$cuser/.local/Cellar
    find /home/$cuser/.local -regex .\+/linuxbrew$ -print | xargs rm -rf
    find /home/$cuser/.local -regex .\+/homebrew$ -print | xargs rm -rf
    find -L /home/$cuser/.local -type l -delete
    exit 0
fi

# Check for required software.
! git --version > /dev/null 2>&1 && _exit 'Git is not available.' 127

# Install Linuxbrew.
echo '==> Install Linuxbrew from github.'
_mkdir $cuser $bin_location || _exit 'Fail to create directory for brew binaries.'
_mkdir $cuser $brew_location || _exit 'Fail to create directory for cloning Linuxbrew.'
_mkdir $cuser $man_location
# Clone source code from github.
git clone -q --depth 1 https://github.com/Linuxbrew/brew.git $brew_location 2> /dev/null
if [ $? -ne 0 ]; then
    # If directory is not empty try `git pull`.
    git --git-dir=$brew_location/.git --work-tree=$brew_location pull -q 2>/dev/null
    [ $? -ne 0 ] && _exit "Fail to clone Linuxbrew into '$brew_location'."
fi
chown -R $cuser:$(id -gn $cuser) $brew_location

# Create symlink for Linuxbrew binary.
ln -fs $brew_location/bin/brew $bin_location/brew
chown -h $cuser:$(id -gn $cuser) $bin_location/brew
# Create symlinks for Linuxbrew man pages.
ln -fs $brew_location/manpages/brew* $man_location
chown -h $cuser:$(id -gn $cuser) $man_location/brew*
