#!/usr/bin/env bash
# Install different Lint engines.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install lint engines, code static analyzers and style checkers.
PHP tools: phpcs, phpcbf, phpstan, php-cs-fixer
Vim tools: vint
OPTION:
    -h      Show this message.

EOF
    exit 1
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

# Get available python version.
function get_python_version() {
    for py_version in 3 2; do
        if python$py_version -m pip --version > /dev/null 2>&1; then
            echo $py_version
            return 0
        fi
    done
    return 127
}

# Retrive latest tag name for github repository.
# Args:
#   $1  Repository name.
function github_get_repo_tag() {
    local tag=$(wget -qO - "https://api.github.com/repos/$1/tags" | \
        grep --color=never -oP '(?<="name": ")[\w\.]+\.\d+' | sort -V | tail -n 1)
    echo -n $tag
    [ -n "$tag" ]
}

# Download binary of specified version from github.
# Args:
#   $1  Repository name.
#   $2  Tag/version name.
#   $3  File name.
#   $4  Download location.
function github_download_releas() {
    wget -qO - "https://github.com/$1/releases/download/$2/$3" > "$4"
}

# Install binary from repository release page.
# Args:
#   $1  System user name.
#   $2  Repository name.
#   $3  File name.
#   $4  Install directory.
function github_install_bin_releas() {
    declare tag; tag=$(github_get_repo_tag "$2")
    if [ $? -ne 0 ]; then
        echo "Fail to retriev tag name for repo '$2'."
        return 1
    fi
    for fname in $3; do
        local lfname="$4/${fname%.*}"
        github_download_releas "$2" "$tag" "$fname" "$lfname"
        if [ $? -eq 0 ]; then
            chown $1:$(id -gn $1) "$lfname"
        else
            rm -f "$lfname"
            echo "Fail to download binary '$fname $tag' from repo '$2'."
        fi
    done
}

# Default values.
[ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER
php_version=$(php --version 2> /dev/null | grep --color=never -oiP '(?<=php )\d\.\d+')
python_version=$(get_python_version)

# Process arguments.
while getopts ":h" OPTION; do
    case $OPTION in
        *) show_usage;;
    esac
done

# Validate user.
if [ $cuser = 'root' ]; then
    echo 'Error: Can not perform installation for root user.'
    exit 126
fi

# Binaries locations.
bin_location=/home/$cuser/.local/bin
_mkdir $cuser $bin_location || _exit 'Fail to create directory to place binaries.'

# PHP
if [ -n "$php_version" ]; then
    echo '==> Install PHP Code Sniffer.'
    github_install_bin_releas $cuser 'squizlabs/php_codesniffer' 'phpcs.phar phpcbf.phar' $bin_location
    echo '==> Install PHPStan.'
    github_install_bin_releas $cuser 'phpstan/phpstan' 'phpstan.phar' $bin_location
    echo '==> Install PHP Code Standard Fixer.'
    github_install_bin_releas $cuser 'friendsofphp/php-cs-fixer' 'php-cs-fixer.phar' $bin_location
fi

# Vim
if [ -n "$python_version" ]; then
    echo '==> Install Vint - Vim script language lint.'
    _eval $cuser "python$python_version -m pip install --user -qq --upgrade setuptools"
    _eval $cuser "python$python_version -m pip install --user -qq --upgrade ansicolor PyYAML vim-vint"
fi
