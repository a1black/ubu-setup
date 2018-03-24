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

function _exit() {
    echo "Error: $1"
    echo '       Abort Nginx installation.'
    exit ${2:-1}
}

# Process arguments.
while getopts ":hu:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user '$OPTARG'.";;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126
# Check user name.
[ "$cuser" = 'root' ] && _exit 'Can not configure Nginx to run as root.' 2
# Check if Nginx is installed.
nginx -v > /dev/null 2>&1 && _exit 'Nginx is already installed.'

echo '==> Add Nginx APT repository.'
sudo add-apt-repository -y ppa:nginx/stable
sudo apt-get update -qq

echo '==> Install Nginx HTTP server.'
sudo apt-get install -qq nginx

echo '==> Configure Nginx.'
if [ -f /etc/nginx/nginx.conf ]; then
    # Sets the bucket size for the server names hash tables.
    sudo sed -i.orig 's/\(#\s*\)\?\(server_names_hash_bucket_size\).*/\2 64;/' \
        /etc/nginx/nginx.conf
    # Run Nginx as user.
    if [[ -n "$cuser" && $cuser != 'root' ]]; then
        sudo sed -i "s/user www-data;/user $cuser;/" /etc/nginx/nginx.conf
        sudo usermod -a -G www-data $cuser
    fi
fi

# Restart nginx server.
sudo service nginx restart

# Configure Nginx+PHP-FPM.
if php --version > /dev/null 2>&1; then
    find /etc/php -type f -regex .+/fpm/php\.ini -print | \
        xargs sudo sed -i 's/^;\?\(cgi\.fix_pathinfo\)=.*/\1=0/'
fi

# Download scripts for managing NGINX.
nginx_scr_git="https://raw.githubusercontent.com/fideloper/Vaprobash/master/helpers"
nginx_scr=/usr/local/bin/ngxcb
if [ ! -f $nginx_scr ]; then
    echo '==> Download script for creating a new Nginx Server Block: $nginx_scr'
    sudo wget -qO $nginx_scr $nginx_scr_git/ngxcb.sh
    sudo chmod ug+x $nginx_scr
fi
