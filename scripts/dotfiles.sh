#!/usr/bin/env bash
# Clone dotfiles fron git repository into user home directory.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Clone dotfiles from git repository into ~/.dotfiles and
create hard links to them in user home directory.
OPTION:
    -u      Copy dotfiles into \$HOME of provided user (default current user).
    -c      HTTP link for cloning git repository.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    exit ${2:-1}
}

# Travers dotfile directory and recreate it structure
# in user home directory using hard links.
# Args:
#   $1  Path in dotfiles.
#   $2  Respective path in home directory.
function linkdot() {
    for filename in $1/* ; do
        local fname=$(basename "$filename")
        if [[ "$fname" = .git || "${fname,,}" = readme.md || "${fname^^}" = LICENSE  ||  ! -r "$filename" ]]; then
            continue
        elif [ -d "$filename" ]; then
            local newdir="$2/$fname"
            _mkdir "$newdir" "$3"
            if [ $? -ne 0 ]; then
                echo "Error: Can't create directory '$newdir' to put dotfiles."
                continue
            fi
            linkdot "$filename" "$newdir" "$3"
        elif [ -f "$filename" ]; then
            ln -f "$filename" "$2/$fname"
        fi
    done
}

# Create directory.
# Args:
#   $1  Directory name.
#   $2  Set directory owner.
function _mkdir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        [ $? -ne 0 ] && return 1
        _chown "$2" "$1"
        [ $? -ne 0 ] && return 1
    fi
    return 0
}

# Change the owner and group for provided file.
# Args:
#   $1  Optional flag '-R' for recursive operation.
#   $2  Owner name.
#   $3  Path to file.
function _chown() {
    local rec=''
    if [ "$1" = '-R' ]; then
        rec='-R'
        shift
    fi
    bash -c "chown --quiet -h $rec $1:$(id -gn $1) $2"
    return $?
}

# Process arguments.
while getopts ":hu:c:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user '$OPTARG'.";;
        c) dot_git="${OPTARG%%/}";;
        *) show_usage;;
    esac
done

# Determine user.
[ -z "$cuser" ] && { [ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER; }

# Check privileges.
if [ $cuser = 'root' ]; then
    _exit 'Can not create dotfiles for root user.' 126
elif [[ $UID -ne 0 && $cuser != $USER ]]; then
    _exit "No privileges to create dotfiles for $cuser user." 126
fi

# Check for required software.
! git --version > /dev/null 2>&1 && _exit 'Git is not available.' 127
! wget --version > /dev/null 2>&1 && _exit 'Wget is not available.' 127

# Check if dotfiles URL is valid.
if [ -z "$dot_git" ]; then
    _exit 'Specify URL on git repository.' 2
elif ! [[ "$dot_git" =~ ^https?://[-a-zA-Z0-9_\+%@.:]+(/[-a-zA-Z0-9_\+%.]+)*$ ]]; then
    _exit 'Specify URL of following type: https://github.com/user/dotfiles.git' 2
fi

# Check if dotfiles URL exists.
wget -q --no-cookies --spider --timeout=2 --tries=2 "$dot_git" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    _exit "Repository '$dot_git' does not exist."
fi

# Check dotfile directory.
dot_location=/home/$cuser/.dotfiles
_mkdir $dot_location $cuser
[ $? -ne 0 ] && _exit "Fail to create directory '$dot_location' to clone dotfiles."
git clone -q --depth 1 $dot_git $dot_location 2> /dev/null
if [ $? -ne 0 ]; then
    # Try `git pull`
    git --git-dir=$dot_location/.git --work-tree=$dot_location pull -q 2> /dev/null
    [ $? -ne 0 ] && _exit "Fail to clone dotfiles from '$dot_git'."
fi
_chown -R $cuser $dot_location

echo '==> Create hard links to dotfiles in home directory.'
# Enable globbing of hidden files.
shopt -s dotglob 2> /dev/null
shopt -s nullglob 2> /dev/null
# Create hard link to dotfiles in user home directory.
linkdot /home/$cuser/.dotfiles /home/$cuser $cuser
