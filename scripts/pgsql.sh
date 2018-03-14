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

function _exit () {
    echo "Error: $1";
    echo "       Abort PostgreSQL installation."
    exit 1
}

# Get Ubuntu code name.
function codename() {
    local name=$(lsb_release -sc)
    [ $name = 'artful' ] && name=xenial
    echo "$name"
    return 0
}

# Cut version number to major release number.
function process_version() {
    local ver="$1"
    [ -z "$ver" ] && read ver
    if [[ "$ver" =~ ^(9\.[0-9]) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$ver" =~ ^(1[0-9]) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        return 1
    fi
    return 0
}

# Find executable for specific version of PostgreSQL.
function find_bin_postgres() {
    local psql_bin=$(find /usr -executable -type f -regex ^.\+$1/bin/postgres$)
    echo "$psql_bin"
    if [ -e "$psql_bin" ]; then
        echo "$psql_bin"
        return 0
    fi
    return 1
}

# Default values.
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"
UBU_SETUP_DRY=1

# Process arguments.
while getopts ":hr:" OPTION; do
    case $OPTION in
        r) psql_version="$OPTARG";;
        h) show_usage;;
    esac
done

if [ -n "$psql_version" ]; then
    # Check version number provided by user.
    psql_version=$(process_version "$psql_version")
    [ $? -ne 0 ] && _exit "Invalid version number."

    # Check if Postgres is already installed.
    psql_bin=$(find_bin_postgres "$psql_version")
    if [ $? -eq 0 ]; then
        _exit "PostgreSQL is already installed."
    fi
fi

# Add PostgreSQL APT repository.
repos_url=http://apt.postgresql.org/pub/repos/apt
repos_dist=$(codename)-pgdg

grep -qi --include=*\.list -e "^deb .\+postgresql.\+ $repos_dist" \
    /etc/apt/sources.list /etc/apt/sources.list.d/*
if [ $? -ne 0 ]; then
    wget -q --spider --timeout=2 --tries=2 $repos_url/dists/$repos_dist > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        _exit "Can't add APT repository for Ubuntu $(lsb_release -sc)"
    fi
    echo "==> Add PostgreSQL APT repository."
    wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
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
echo "==> Installing PostgreSQL"
if [ -z "$psql_version" ]; then
    sudo apt-get install -qq postgresql postgresql-contrib
else
    sudo apt-get install -qq postgresql-$psql_version
fi

# Start Postgres.
sudo service postgresql start

# Setup passwords.
if [ -z "$psql_version" ]; then
    # Change default password for user `postgres`.
    echo "==> Changre default Postgres password."
    sudo -u postgres psql -d postgres -c '\password postgres'

    # Create new super user.
    echo "==> Create new superuser \"$cuser\"."
    sudo -u postgres createuser --superuser $cuser
    echo "==> Set password for user \"$cuser\"."
    sudo -u postgres psql -d postgres -c '\password $cuser'
fi

# Configure main running Postgres server.
if [ -z "$psql_version" ]; then
    psql_version=$(psql --version 2> /dev/null | cut -d ' ' -f 3 | process_version)
fi
echo "==> Configure PostgreSQL $psql_version"
# Listen across different networks.
sudo sed -i -e '/^#listen_addresses/s/localhost/*/' -e '/^#listen_addresses/s/#//' \
    /etc/postgresql/$psql_version/main/postgresql.conf

# Change the authentication method from peer to md5.
# This way Postgres separates own users from system users.
echo "host    all             all             0.0.0.0/0               md5" | \
    sudo tee --append /etc/postgresql/$psql_version/main/pg_hba.conf > /dev/null

# Restart Postgres.
sudo service postgresql restart
