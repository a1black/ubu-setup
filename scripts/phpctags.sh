#~/usr/bin/env bash
# Install PHPCtags. (https://github.com/vim-php/phpctags)

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install an enhanced php ctags index generator.
OPTION:
    -l      Install locally for current user.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort PHP Ctags installation.'
    exit ${2:-1}
}

# Execute command.
# Args:
#   $1  Run as user.
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
phpctags_local=1

# Process arguments.
while getopts ":hl" OPTION; do
    case $OPTION in
        l) phpctags_local=0;;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126
[[ $phpctags_local -eq 0 && $cuser = 'root' ]] && _exit 'Can not install for root user.' 126
# Check required software.
git --version > /dev/null 2>&1 || _exit 'Git is not available.' 127
php --version > /dev/null 2>&1 || _exit 'PHP is not available.' 127
_eval $cuser 'composer --version' > /dev/null 2>&1 || _exit 'Composer is not available.' 127

# Determine path for placing PHP Ctags binaries.
phpctags_location=/usr/local
[ $phpctags_local -eq 0 ] && phpctags_location=/home/$cuser/.local

# Create all required directories.
if [ $phpctags_local -eq 0 ]; then
    _mkdir $cuser $phpctags_location/bin || _exit 'Fail to create directory for PHP Ctags binaries.'
fi

echo '==> Install PHP Ctags from source code.'
echo '==> Install dependencies.'
sudo apt-get update -qq
sudo apt-get install -qq build-essential pkg-config automake

# Download source code.
echo '==> Download source code.'
phpctags_tmp=$(mktemp -dq)
git clone -q --depth 1 https://github.com/vim-php/phpctags.git $phpctags_tmp 2> /dev/null
[ $? -ne 0 ] && _exit 'Fail to download PHP Ctags source code.'
chown -R $cuser:$(id -gn $cuser) $phpctags_tmp
cd $phpctags_tmp > /dev/null

# Build and install.
echo '==> Download dependencies from Packagist.'
_eval $cuser "cd $phpctags_tmp; composer install -q" > /dev/null 2>&1
make

cp $phpctags_tmp/build/phpctags.phar $phpctags_location/bin/phpctags
if [[ $? -eq 0 && $phpctags_local -eq 0 ]]; then
    chown $cuser:$(id -gn $cuser) $phpctags_location/bin/phpctags
fi

# Clean-up.
cd - > /dev/null
rm -rf $phpctags_tmp

[ ! -e $phpctags_location/bin/phpctags ] && _exit 'Fail to build PHP Ctags binary.'
