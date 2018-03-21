#!/usr/bin/env bash
# Install command-line fuzzy-finder. (https://github.com/junegunn/fzf)

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install command-line fuzzy finder FZF.
More information can be found on https://github.com/junegunn/fzf
OPTION:
    -d      Delete fzf.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1";
    echo "       Abort fzf installation."
    exit 1
}

# Create directory.
# Args:
#   $1 - Directory name.
#   $2 - Set directory owner.
function _mkdir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        [ $? -ne 0 ] && return 1
        _chown "$2" "$1"
        if [ $? -ne 0 ]; then
            rm -rf "$1"
            return 1
        fi
    fi
    return 0
}

# Change the owner and group for provided file.
# Args:
#   $1 - Optional flag '-R' for recursive operation.
#   $2 - Owner name.
#   $3 - Path to file.
function _chown() {
    local rec=''
    if [ "$1" = '-R' ]; then
        rec='-R'
        shift
    fi
    echo "chown $rec $1:$(id -gn $1) $2"
    bash -c "chown --quiet -h $rec $1:$(id -gn $1) $2"
    return $?
}


# Execute command.
# Args:
#   $1 - Run as user.
#   $2 - Command to execute.
function _eval() {
    if [ $UID -eq 0 ]; then
        sudo -iH -u "$1" bash -c "$2"
    else
        bash -c "$2"
    fi
    return $?
}

# Default values.
[ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER
fzf_uninstall=1

# Process arguments.
while getopts ":hd" OPTION; do
    case $OPTION in
        d) fzf_uninstall=0;;
        h) show_usage;;
    esac
done

# Verify privilages.
if [ $cuser = 'root' ]; then
    _exit "Script can only perform local package manipulation."
fi

fzf_location=/home/$cuser/.local/share/fzf
bin_location=/home/$cuser/.local/bin
man_location=/home/$cuser/.local/man/man1

# Delete fzf source code, config and binaries.
if [ $fzf_uninstall -eq 0 ]; then
    echo "==> Delete fzf."
    _eval $cuser "cd $fzf_location && bash -- uninstall"
    rm -rf $fzf_location
    find -L /home/$cuser/.local -type l -delete
    exit 0
fi

# Install fzf.
echo "==> Create all required directories."
_mkdir $fzf_location $cuser || _exit "Fail to create directory for cloning fzf."
_mkdir $bin_location $cuser || _exit "Fail to create directory for fzf binaries."
_mkdir $man_location $cuser
echo "==> Clone fzf source code."
git clone -q --depth 1 https://github.com/junegunn/fzf.git $fzf_location 2> /dev/null
if [ $? -ne 0 ]; then
    # Try to execute `git pull`.
    git --git-dir=$fzf_location/.git --work-tree=$fzf_location pull -q 2> /dev/null
    [ $? -ne 0 ] && _exit "Fail to retrieve fzf source code from github."
fi
_chown -R $cuser $fzf_location

echo "==> Install fzf."
_eval "$cuser" "cd $fzf_location && bash -- install --no-update-rc --completion --key-bindings"

# Create symlinks for fzf binaries.
ln -fs $fzf_location/bin/fzf* $bin_location
_chown $cuser "$bin_location/fzf*"
# Create symlinks for fzf man pages.
ln -fs $fzf_location/man/man1/fzf* $man_location
_chown $cuser "$man_location/fzf*"
