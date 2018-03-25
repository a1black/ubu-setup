#!/usr/bin/env bash
# Install PostgreSQL Server and client.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest stable version of PostgreSQL.
OPTION:
    -r      Install specified version of PostgreSQL.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort PostgreSQL installation.'
    exit ${2:-1}
}

# Get Ubuntu code name.
function codename() {
    local name=$(lsb_release -sc 2> /dev/null)
    [[ -z "$name" || "$name" = 'artful' ]] && name=xenial
    echo "$name"
}

# Cut version number to major release number.
# Args:
#   stdin|$1  Version number.
function process_version() {
    local version="$1"
    [ -z "$version" ] && read version
    if [[ "$version" =~ ^(9\.[0-9]) ]]; then
        echo ${BASH_REMATCH[1]}
    elif [[ "$version" =~ ^(1[0-9]) ]]; then
        echo ${BASH_REMATCH[1]}
    else
        [ 1 -eq 0 ]
    fi
}

# Find executable for specific version of PostgreSQL.
# Args:
#   $1  Postgres version.
function find_bin_postgres() {
    local bins=$(find /usr/lib/postgresql -type f -executable -regex ^.\+$1/bin/postgres$ 2> /dev/null)
    [ -n "$bins" ] && echo "$bins"
}

# Process arguments.
while getopts ":hr:" OPTION; do
    case $OPTION in
        r) psql_version="$OPTARG";;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126

if [ -n "$psql_version" ]; then
    # Check version number provided by user.
    psql_version=$(process_version "$psql_version")
    [ $? -ne 0 ] && _exit 'Invalid version number.' 2
fi

# Check if Postgres is already installed.
psql_bin=$(find_bin_postgres)
[ $? -eq 0 ] && _exit 'PostgreSQL is already installed.'

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

# Check if requested version is present in APT repository.
if [ -n "$psql_version" ]; then
    apt-cache show postgresql-$psql_version > /dev/null 2>&1
    [ $? -ne 0 ] && _exit "PostgreSQL $psql_version is not present in APT repository."
fi

# Install and configure Postgres.
echo '==> Installing PostgreSQL.'
if [ -z "$psql_version" ]; then
    sudo apt-get install -qq postgresql postgresql-contrib
else
    sudo apt-get install -qq postgresql-$psql_version
fi

# Start Postgres.
sudo service postgresql start 2> /dev/null

# Configure PostgeSQL installed from virtual package.
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"

# Change default password for user 'postgres'.
echo '==> Changre default Postgres password.'
sudo -u postgres psql -d postgres -c '\password postgres'

if [ $cuser != 'root' ]; then
    # Create new super user.
    echo "==> Create new superuser '$cuser'."
    sudo -u postgres createuser --superuser $cuser
    echo "==> Set password for user '$cuser'."
    sudo -u postgres psql -d postgres -c "\\password $cuser"
fi

# Get version of main running Postgres server.
if [ -z "$psql_version" ]; then
    psql_version=$(psql --version 2> /dev/null | cut -d ' ' -f 3 | process_version)
    [ $? -ne 0 ] && exit 0
fi

echo "==> Configure PostgreSQL $psql_version"
psql_config=/etc/postgresql/$psql_version/main/postgresql.conf
if [ -f "$psql_config" ]; then
    # Listen across different networks.
    sudo sed -i.orig "s/^#\?\(listen_addresses\) = '.\+'/\1 = '*'/" "$psql_config"
fi

# Change the authentication method from peer to md5.
# This way Postgres separates own users from system users.
psql_hba=/etc/postgresql/$psql_version/main/pg_hba.conf
if [ -f "$psql_hba" ]; then
    echo "host    all             all             0.0.0.0/0               md5" | \
        sudo tee --append "$psql_hba" > /dev/null
fi

# Restart Postgres.
sudo service postgresql restart
