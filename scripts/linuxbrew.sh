#!/usr/bin/env bash
# Install package manager Linuxbrew.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install package manager Linuxbrew.
Script will copy source code of Linuxbrew '~/.local/share/linuxbrew'
and create symlink '~/.local/bin/brew' for Linuxbrew binary.
OPTION:
    -u      Install package for specified user (default current user).
    -d      Delete Linuxbrew if installed.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1";
    echo "       Abort Linuxbrew installation."
    exit 1
}

# Default values.
cuser=$USER
brew_uninstall=1

# Process arguments.
while getopts ":hdu:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        d) brew_uninstall=0;;
        h) show_usage;;
    esac
done

[[ "$cuser" = 'root' && -n "$SUDO_USER" ]] && cuser=$SUDO_USER
# Validate parameters.
if [ "$cuser" = 'root' ]; then
    _exit "Linuxbrew can only be installed/uninstalled locally."
elif [[ $UID -ne 0 && "$cuser" != $USER ]]; then
    _exit "Run script with root privileges."
fi

# Delete Linuxbrew source code.
if [ $brew_uninstall -eq 0 ]; then
    if [ $UID -eq 0 ]; then
        brew_pkgs=$(sudo -iH -u $cuser brew list 2> /dev/null)
    else
        brew_pkgs=$(brew list 2> /dev/null)
    fi
    [ $? -ne 0 ] && _exit "Linuxbrew is not installed."
    for pkg in $brew_pkgs; do
        if [ $UID -eq 0 ]; then
            sudo -iH -u $cuser brew rm -f --ignore-dependencies $pkg > /dev/null 2>&1
        else
            brew rm -f --ignore-dependencies $pkg > /dev/null 2>&1
        fi
    done
    rm -rf /home/$cuser/.local/Cellar
    find /home/$cuser/.local -regex .\+/linuxbrew$ -print | xargs rm -rf
    find /home/$cuser/.local -regex .\+/homebrew$ -print | xargs rm -rf
    find -L /home/$cuser/.local -type l -delete
    exit 0
fi

# Install Linuxbrew.
brew_location=/home/$cuser/.local/share/linuxbrew
bin_location=/home/$cuser/.local/bin
if git --version > /dev/null 2>&1; then
    echo "==> Install Linuxbrew from github."
    mkdir -p $brew_location 2> /dev/null
    [ $? -ne 0 ] && _exit "Fail to create directory for cloning Linuxbrew source code."
    # Clone source code from github.
    git clone -q https://github.com/Linuxbrew/brew.git $brew_location 2> /dev/null
    if [ $? -ne 0 ]; then
        # If directory is not empty try `git pull`.
        git --git-dir=$brew_location/.git --work-tree=$brew_location pull -q 2>/dev/null
        [ $? -ne 0 ] && _exit "Fail to clone Linuxbrew into '$brew_location'."
    else
        chown -R $cuser:$(id -gn $cuser) $brew_location
    fi
    # Create symlink for Linuxbrew binary.
    if [ ! -d "$bin_location" ]; then
        mkdir -p $bin_location 2> /dev/null
        [ $? -ne 0 ] && _exit "Add '$brew_location/bin' to \$PATH."
        chown $cuser:$(id -gn $cuser) $bin_location
    fi
    ln -sf $brew_location/bin/brew $bin_location/brew
    chown $cuser:$(id -gn $cuser) $bin_location/brew
else
    _exit "Git is required for Linuxbrew installation."
fi
