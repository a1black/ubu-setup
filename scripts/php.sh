#!/usr/bin/env bash
# Install PHP program languge packages.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install PHP or HHVM.
OPTION:
    -r      Install specific version of Vagrant.
    -h      Show this message.

EOF
    exit 1
}

function _exit () {
    echo "Error: $1";
    echo "       Abort PHP installation."
    exit 1
}

# Process arguments.
while getopts ":hr:" OPTION; do
    case $OPTION in
        r) php_version="$OPTARG";;
        h) show_usage;;
    esac
done

if [ "${php_version,,}" = 'hhvm' ]; then
    php_version='hhvm'
elif ! [[ "$php_version" =~ ^[57]\.[0-9]+$ ]]; then
    _exit "Invalid PHP version."
fi

# Install HHVM or PHP packages.
if [[ $php_version = 'hhvm' ]]; then
    grep -qi --include=*\.list -e "^deb .\+hhvm" /etc/apt/sources.list /etc/apt/sources.list.d/*
    if [ $? -ne 0 ]; then
        echo "==> Add HHVM APT repository."
        wget -qO - http://dl.hhvm.com/conf/hhvm.gpg.key | sudo apt-key add -
        echo "deb http://dl.hhvm.com/ubuntu $(lsb_release -sc) main" | \
            sudo tee /etc/apt/sources.list.d/hhvm.list > /dev/null
        sudo apt-get update -qq
    fi
    echo "==> Install HHVM."
    sudo apt-get install -qq hhvm
    # Start HHVM on system boot.
    sudo update-rc.d hhvm default > /dev/null 2>&1
    # Create symlink to assosiate `php` command with `hhvm`.
    sudo /usr/bin/update-alternatives --install /usr/bin/php php /usr/bin/hhvm 60
    # Start HHVM.
    sudo service hhvm restart
else
    if [ -z "$php_version" ]; then
        php --version > /dev/null 2>&1 && _exit "PHP already installed."
        echo "==> Install system virtual package \`php\`."
    else
        # Look for package in native repository.
        apt-cache show "php$php_version" 2> /dev/null | grep -q '^Version:'
        if [ $? -ne 0 ]; then
            echo "==> Add PHP unofficial PPA."
            sudo add-apt-repository -y ppa:ondrej/php
            sudo apt-get update -qq
        fi
        # Look for package in added repository.
        apt-cache show "php$php_version" 2> /dev/null | grep -q '^Version:'
        [ $? -ne 0 ] && _exit "Can't locate PHP $php_version package."
        echo "==> Install PHP $php_version program language."
    fi
    sudo apt-get install -qq php${php_version}-{cli,fpm,mysql,pgsql,sqlite,memcached,curl,\
mbstring,mcrypt,gd,gmp,imagick,intl,xml} php-xdebug

    # Configure installed PHP package.
    php_version=$(php --version 2> /dev/null | grep --color=never -oP '(?<=^PHP )\d+\.\d+')
    [ $? -ne 0 ] && exit 1
    echo "==> Configure PHP FPM."
    # Listen TCP socket instead Unix socket.
    sudo sed -i.orig 's/^listen =.+/listen = 127.0.0.1:9000/' /etc/php/$php_version/fpm/pool.d/www.conf
    # Enable allowed client IP addresses.
    sudo sed -i 's/;\(listen.allowed_clients\)/\1/' /etc/php/$php_version/fpm/pool.d/www.conf
    # PHP error reporting.
    sudo sed -i.orig '/^display_errors =/c display_errors = On' /etc/php/$php_version/fpm/php.ini
    sudo sed -i '/^error_reporting =/c error_reporting = E_ALL' /etc/php/$php_version/fpm/php.ini
    # PHP Xdebug configuration.
    sudo tee /etc/php/$php_version/mods-available/xdebug.ini > /dev/null 2>&1 << EOF
zend_extension=xdebug.so
xdebug.remote_enable = 1
xdebug.remote_connect_back = 1
xdebug.remote_port = 9000
xdebug.scream = 0
xdebug.cli_color = 1
xdebug.show_local_vars = 1
xdebug.var_display_max_depth = 5
xdebug.var_display_max_children = 256
xdebug.var_display_max_data = 1024
EOF

    # Set PHP timezone.
    php_timezone=$(cat /etc/timezone)
    if [ -n "$php_timezone" ]; then
        sudo sed -i "/^;date.timezone/c date.timezone = $php_timezone" \
            /etc/php/$php_version/fpm/php.ini /etc/php/$php_version/cli/php.ini 2> /dev/null
    fi
    sudo service php${php_version}-fpm restart
fi
