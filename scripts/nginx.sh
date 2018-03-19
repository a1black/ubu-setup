#!/usr/bin/env bash
# Install Nginx HTTP server.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest stable version of Nginx HTTP server.
OPTION:
    -u      Run Nginx server as USER.
    -h      Show this message.

EOF
    exit 1
}

function _exit () {
    echo "Error: $1";
    echo "       Abort Nginx installation."
    exit 1
}

# Process arguments.
while getopts ":hu:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        h) show_usage;;
    esac
done

# Check if Nginx is installed.
if nginx -v > /dev/null 2>&1; then
    _exit "Nginx is already installed."
fi

# Check Nginx APT repository in source list.
grep -qi --include=*\.list -e "^deb .\+nginx" \
    /etc/apt/sources.list /etc/apt/sources.list.d/*
if [ $? -ne 0 ]; then
    echo "==> Add Nginx APT repository."
    sudo add-apt-repository -y ppa:nginx/stable
    sudo apt-get update -qq
fi

echo "==> Install Nginx HTTP server."
sudo apt-get install -qq nginx

echo "==> Configure Nginx."
# Sets the bucket size for the server names hash tables.
sudo sed -i.orig 's/\(#\s*\)\?\(server_names_hash_bucket_size\).*/\2 64;/' \
    /etc/nginx/nginx.conf
# Run Nginx as user.
if [[ -n "$cuser" && "$cuser" != 'root' ]]; then
    sudo sed -i 's/user www-data;/user $cuser;/' /etc/nginx/nginx.conf
    sudo usermod -a -G www-data $cuser
fi

# Configure Nginx+PHP-FPM.
if php --version > /dev/null 2>&1; then
    find /etc/php -type f -regex .+/fpm/php\.ini -print | \
        xargs sudo sed -i 's/^;\?\(cgi\.fix_pathinfo\)=.*/\1=0/'
fi

# Download scripts for managing NGINX.
nginx_scr_git="https://raw.githubusercontent.com/fideloper/Vaprobash/master/helpers"
nginx_scr=/usr/local/bin
if [ ! -f "$nginx_scr/ngxcb" ]; then
    echo "==> Download script for creating a new Nginx Server Block \`$nginx_scr/ngxcb\`."
    sudo wget -q -O $nginx_scr/ngxcb "$nginx_scr_git/ngxcb.sh"
    sudo chmod ug+x $nginx_scr/ngxcb
fi
