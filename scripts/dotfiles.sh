#!/usr/bin/env bash
# Clone dotfiles fron git repository into user home directory.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Clone dotfiles from git repository into ~/.dotfiles and
create hard links to them in user home directory.
OPTION:
    -u      User who will recieve dotfiles.
    -c      HTTP link for cloning git repository.
    -h      Show this message.

EOF
    exit 1
}

function _exit () {
    echo "Error: $1";
    exit 1
}

# Travers dotfile directory and recreate it structure
# in user home directory using hard links.
# Args:
#   $1  Path in dotfiles.
#   $2  Respective path in home directory.
function linkdot() {
    for filename in $1/* ; do
#        local fname="${filename##/*/}"
        local fname=$(basename "$filename")
        if [[ "$fname" = .git || "${fname,,}" = readme.md || "${fname^^}" = LICENSE ]] || [ ! -r "$filename" ]; then
            continue
        elif [ -d "$filename" ]; then
            local newdir="$2/$fname"
            if [[ -e "$newdir" && ! -d "$newdir" ]]; then
                echo "Error: Can't create directory \`$newdir\` to put dotfiles."
                continue
            elif [ ! -d "$newdir" ]; then
                mkdir -p $newdir
                chown $cuser:$cuser $newdir
            fi
            linkdot "$filename" "$newdir"
        elif [ -f "$filename" ]; then
            ln -f $filename $2/$fname
        fi
    done
}

# Default values.
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"
dot_git="https://github.com/a1black/dotfiles.git"

# Process arguments.
while getopts ":hu:c:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        c) dot_git="${OPTARG%%/}";;
        h) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $EUID -ne 0 && $cuser != $USER ]]; then
    _exit "Run script with root privileges."
fi

# Check if dotfiles URL is valid.
dot_git_regex='^(https?://)?[-a-zA-Z0-9_\+%@.:]+(/[-a-zA-Z0-9_\+%.]+)*$'
if [[ "$dot_git" =~ $dot_git_regex ]]; then
    [ -z "${BASH_REMATCH[1]}" ] && dot_git="https://$dot_git"
else
    _exit "Specify URL of following type: \"[https://]github.com/user/dotfiles.git\"."
fi

# Check if dotfiles URL exists.
wget -q --no-cookies --spider --timeout=2 --tries=2 "$dot_git" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    _exit "Repository \"$dot_git\" does not exist."
fi

# Enable globbing of hidden files.
shopt -s dotglob 2> /dev/null

# Check dotfile directory.
dot_dir="/home/$cuser/.dotfiles"
if [[ -e "$dot_dir" && ! -d "$dot_dir" ]]; then
    _exit "Can't create directory to store dotfiles."
elif [ -d "$dot_dir" ]; then
    for filename in $dot_dir/* ; do
        [ ! -e "$filename" ] && continue
        _exit "Can't clone dotfiles, because \`$dot_dir\` is not empty."
    done
fi

# Clone dotfiles form repository.
git clone -q $dot_git $dot_dir
if [ $? -ne 0 ]; then
    _exit "Fail clone dotfiles from \`$dot_git\`."
fi

# Create hard link to dotfiles in user home directory.
echo "==> Create hard links to dotfiles in home directory."
linkdot "/home/$cuser/.dotfiles" "/home/$cuser"
