#!/usr/bin/env bash
# Install MySQL Server.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest stable version of MySQL Server.
OPTION:
    -r      Install specific version of MySQL Server.
    -h      Show this message.

EOF
    exit 1
}

function _exit () {
    echo "$1";
    echo "       Abort MySQL installation."
    exit 1
}

# Get Ubuntu code name.
function codename() {
    if [ "$1" = "5.6" ]; then
        echo xenial
    else
        lsb_release -sc
    fi
}

# Default and global values.
MYSQL_ROOT_PASS=root

# Process arguments.
while getopts ":hr:" OPTION; do
    case $OPTION in
        r) mysql_version="$OPTARG";;
        h) show_usage;;
    esac
done

# Check if MySQL is already installed.
if mysqld --version > /dev/null 2>&1; then
    _exit "MySQL Server is already installed."
elif ! [[ "$mysql_version" =~ ^5\.[567]$ ]] && [ "$mysql_version" != '8.0' ]; then
# Validate MySQL package version.
    _exit "Invalid MySQL Server version."
elif ! [[ "$MYSQL_ROOT_PASS" =~ ^[-a-zA-Z0-9_]+$ ]]; then
# Validate MySQL root password.
    _exit "Invalid MySQL root password."
fi

# Check if MySQL available in native repository.
mysql_package="mysql-server-$mysql_version"
apt-cache show "$mysql_package" 2> /dev/null | grep -q '^Version:'
if [ $? -ne 0 ]; then
    dist=$(codename $mysql_version)
    grep -qiE --include=*\.list -e "^deb .+repo\.mysql\.com.+ mysql-$mysql_version" \
        /etc/apt/sources.list /etc/apt/sources.list.d/*
    if [ $? -ne 0 ]; then
        echo "==> Run MySQL APT repository configuration."
        sudo apt-get purge -qq mysql-apt-config
        # Add MySQL APT repository.
        sudo apt-key adv --keyserver pgp.mit.edu --recv-keys 5072E1F5
        echo "deb http://repo.mysql.com/apt/ubuntu $dist mysql-apt-config" | \
            sudo tee /etc/apt/sources.list.d/mysql.list > /dev/null
        sudo apt-get update -qq
        # Run APT repository configurator.
        sudo apt-get install mysql-apt-config
        sudo apt-get update -qq
    fi
    # Set new package name.
    mysql_package="mysql-server"

    # Set `root` password for non-interactive installation.
    sudo debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password $MYSQL_ROOT_PASS"
    sudo debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password $MYSQL_ROOT_PASS"
fi

# Install package.
echo "==> Install MySQL Server package \"$mysql_package\"."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq $mysql_package

# Restart MySQL Server.
sudo service mysql restart
