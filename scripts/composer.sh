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

function _exit () {
    echo "Error: $1";
    echo "       Abort Composer installation."
    exit 1
}

# Default values.
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"
composer_global=1

# Process arguments.
while getopts ":hg" OPTION; do
    case $OPTION in
        n) composer_global=0;;
        h) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $composer_global -eq 0 && $EUID -ne 0 ]]; then
    _exit "Run script with root privileges or remove global installation flag."
elif [[ $cuser = 'root' || $composer_global -eq 0 ]]; then
    composer_location=/usr/local/bin
else
    composer_location=/home/$cuser/.local/bin
fi

# Check if PHP package is installed.
php --version > /dev/null 2>&1
PHP_IS_INSTALLED=$?

hhvm --version > /dev/null 2>&1
HHVM_IS_INSTALLED=$?

if [[ $PHP_IS_INSTALLED -ne 0 && $HHVM_IS_INSTALLED -ne 0 ]]; then
    _exit "PHP or HHVM is required to install composer."
fi

# Download Composer binary.
composer_tmp=$(mktemp -qd)
echo "==> Download and run Composer installation script."
if curl --version > /dev/null 2>&1; then
    curl -fsLo $composer_tmp/installer https://getcomposer.org/installer
else
    wget -qO - https://getcomposer.org/installer > $composer_tmp/installer
fi

cmd="$composer_tmp/installer"
if [ $HHVM_IS_INSTALLED -eq 0 ]; then
    hhvm -v ResourceLimit.SocketDefaultTimeout=30 -v Http.SlowQueryThreshold=30000 $composer_tmp/installer --install-dir=$composer_tmp
else
    php $composer_tmp/installer --install-dir=$composer_tmp
fi

# Complete Composer installation.
echo "==> Place Composer binary into \"$composer_location\"."
if [[ $composer_global -ne 0 && ! -e "$composer_location" ]]; then
    mkdir -p $composer_location
    chown $cuser:$(id -gn $cuser) $composer_location
    export PATH="$composer_location:$PATH"
    echo "?!?!?!  Please extend \$PATH with path '$composer_location'."
fi
mv $composer_tmp/composer.phar $composer_location/composer
if [ $composer_global -ne 0 ]; then
    chown $cuser:$(id -gn $cuser) $composer_location/composer
fi
# Clean up.
rm -rf $composer_tmp

# Set Composer installation path.
if [ "$cuser" != 'root' ] && ! grep -q 'COMPOSER_HOME=' "/home/$cuser/.profile"; then
    composer_home=/home/$cuser/.local/lib/composer
    cat << EOF
==> Add following lines into initialization file for login shell ~/.profile
    export COMPOSER_HOME="$composer_home"
    export PATH="\$PATH:\$COMPOSER_HOME/vendor/bin"
EOF
    mkdir -p $composer_home
    chown -R $cuser:$(id -gn $cuser) $composer_home
    cat >> /home/$cuser/.profile << EOF

# Composer global installation path.
export COMPOSER_HOME="$composer_home"
export PATH="\$PATH:\$COMPOSER_HOME/vendor/bin"
EOF
fi

# Recommendations.
composer_recommends=('phpspec/phpspec' 'squizlabs/php_codesniffer')
echo "==> Some of recommended packages to install globaly:"
if [ $HHVM_IS_INSTALLED -eq 0 ]; then
    echo "  hhvm -v ResourceLimit.SocketDefaultTimeout=30 -v Http.SlowQueryThreshold=30000 -v Eval.Jit=false $composer_location/composer global require ${composer_recommends[@]}"
else
    echo "  composer global require ${composer_recommends[@]}"
fi
