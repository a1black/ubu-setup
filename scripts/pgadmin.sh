#!/usr/bin/env bash
# Install pgAdmin - managing tool for PostgreSQL server.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install pgAdmin as a standalone desktop application.
OPTION:
    -r      Install 3 (default) or 4 version of pgAdmin.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort pgAdmin installation.'
    exit ${2:-1}
}

# Get Ubuntu code name.
function codename() {
    local name=$(lsb_release -sc 2> /dev/null)
    [[ -z "$name" || "$name" = 'artful' ]] && name=xenial
    echo "$name"
}

# Default values.
pgadmin_version=3

# Process arguments.
while getopts ":hr:" OPTION; do
    case $OPTION in
        r) pgadmin_version="$OPTARG";;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126
# Check version number.
[[ "$pgadmin_version" =~ ^[34]$ ]] || _exit 'Invalid pgAdmin version number.' 2
# Check if system has GUI layer.
dpkg -l 2> /dev/null | grep -q 'xserver-xorg\s'
[ $? -ne 0 ] && _exit 'Operating system does not have graphical component.' 126

# Add PostgreSQL APT repository.
grep -qi --include=*\.list -e '^deb .\+apt\.postgresql' \
    /etc/apt/sources.list /etc/apt/sources.list.d/*
if [ $? -ne 0 ]; then
    echo '==> Add Postgres APT repository to source list.'
    repos_url=http://apt.postgresql.org/pub/repos/apt
    repos_dist=$(codename)-pgdg

    wget -q --spider --timeout=2 --tries=2 $repos_url/dists/$repos_dist > /dev/null 2>&1
    [ $? -ne 0 ] && _exit "Can't add APT repository for Ubuntu $(codename)"
    wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    [ $? -ne 0 ] && _exit 'Fail to add key for Postgres repository.'
    echo "deb $repos_url $repos_dist main" | \
        sudo tee /etc/apt/sources.list.d/postgresql.list > /dev/null
    sudo apt-get update -qq
fi

# Install pgAdmin.
apt-cache show "pgadmin$pgadmin_version" 2> /dev/null | grep -q '^Version:'
[ $? -ne 0 ] && _exit "Can't locate pgAdmin$pgadmin_version in repository."
echo "==> Install pgAdmin$pgadmin_version"
sudo apt-get install -qq pgadmin$pgadmin_version 2> /dev/null
[ $? -ne 0 ] && _exit "Fail to install pgAdmin$pgadmin_version"
