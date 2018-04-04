#!/usr/bin/env bash
# Install PHP package manager.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install PHP package manager Composer.
Composer is installed locally for current user.
OPTION:
    -g      Install Composer globally.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Composer installation.'
    exit ${2:-1}
}

# Execute command.
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
    _eval $1 "mkdir -p $2"
    [ $? -ne 0 ] && return 1
    chown -R $1:$(id -gn $1) $2
}

# Default values.
[ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER
composer_global=1

# Process arguments.
while getopts ":hg" OPTION; do
    case $OPTION in
        g) composer_global=0;;
        *) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $composer_global -eq 0 && $EUID -ne 0 ]]; then
    _exit 'Run script with root privileges or remove global installation flag.' 126
elif [[ $composer_global -ne 0 && $cuser = 'root' ]]; then
    composer_global=0
fi

# Check if PHP package is installed.
php --version > /dev/null 2>&1
PHP_IS_INSTALLED=$?
hhvm --version > /dev/null 2>&1
HHVM_IS_INSTALLED=$?

if [[ $PHP_IS_INSTALLED -ne 0 && $HHVM_IS_INSTALLED -ne 0 ]]; then
    _exit 'PHP or HHVM is required to install composer.' 127
fi

# Download Composer binary.
composer_tmp=$(mktemp -qd)
echo '==> Download and run Composer installation script.'
wget -qO - https://getcomposer.org/installer > $composer_tmp/installer 2> /dev/null
[ $? -ne 0 ] && _exit 'Fail to download composer installer.'

cmd=$composer_tmp/installer
if [ $HHVM_IS_INSTALLED -eq 0 ]; then
    hhvm -v ResourceLimit.SocketDefaultTimeout=30 -v Http.SlowQueryThreshold=30000 $composer_tmp/installer --install-dir=$composer_tmp
else
    php $composer_tmp/installer --install-dir=$composer_tmp
fi

# Composer installation directory.
composer_location=/usr/local/bin
if [ $composer_global -ne 0 ]; then
    composer_location=/home/$cuser/.local/bin
    _mkdir $cuser $composer_location || _exit 'Fail to create directory for Composer binaries.'
fi

# Complete Composer installation.
echo "==> Place Composer binary into '$composer_location'."
mv -f $composer_tmp/composer.phar $composer_location/composer 2> /dev/null
rm -rf $composer_tmp
[ ! -e $composer_location/composer ] && _exit 'Fail to copy Composer binary.'
if [ $composer_global -ne 0 ]; then
    chown $cuser:$(id -gn $cuser) $composer_location/composer
    echo "Info: Make sure that '$composer_location' in \$PATH."
fi
chmod +x $composer_location/composer

# Set Composer installation path.
grep -qF 'COMPOSER_HOME=' /home/$cuser/.profile 2> /dev/null
if [[ $? -ne 0 && $composer_global -ne 0 ]]; then
    composer_home=/home/$cuser/.local/lib/composer
    cat << EOF
==> Add following lines into initialization file for login shell ~/.profile
    export COMPOSER_HOME="$composer_home"
    export PATH="\$PATH:\$COMPOSER_HOME/vendor/bin"
EOF
    _mkdir $cuser $composer_home
    cat >> /home/$cuser/.profile << EOF

# Composer global installation path.
export COMPOSER_HOME="$composer_home"
export PATH="\$PATH:\$COMPOSER_HOME/vendor/bin"
EOF
fi

# Recommendations.
echo '==> How to install packages globaly:'
if [ $HHVM_IS_INSTALLED -eq 0 ]; then
    echo "hhvm -v ResourceLimit.SocketDefaultTimeout=30 -v Http.SlowQueryThreshold=30000 -v Eval.Jit=false $composer_location/composer global require -o phpunit/phpunit"
else
    echo "$composer_location/composer global require -o phpunit/phpunit=*"
fi
