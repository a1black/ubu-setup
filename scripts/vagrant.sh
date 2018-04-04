#!/usr/bin/env bash
# Install Vagrant package.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest available version of provisioning tool Vagrant.
OPTION:
    -r      Install specific version of Vagrant.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Vagrant installation.'
    exit ${2:-1}
}

# Process arguments.
while getopts ":hr:" OPTION; do
    case $OPTION in
        r) install_ver="$OPTARG";;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126

# Check required software.
sudo apt-get install -qq wget
! wget --version > /dev/null 2>&1 && _exit 'Wget is not available.'

# Check user provided version number.
if [ -n "$install_ver" ] && ! [[ "$install_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    _exit "Invalid version number '$install_ver'." 2
fi

# Check if Vagrant is already installed.
if vagrant --version > /dev/null 2>&1; then
    vagrant_version=$(vagrant --version | cut -d ' ' -f 2)
    _exit 'Vagrant is already installed.'
fi

# Get Vagrant version in system native repository.
vagrant_version=$(apt-cache show vagrant 2> /dev/null | \
    sed -n '/^Version:/{s/\w\+:\s*//g p}' | \
    head -n 1 | grep --color=never -oE "^[0-9]+\.[0-9]+\.[0-9]+")
if [[ -n "$install_ver" && "$install_ver" = "$vagrant_version" ]]; then
    echo '==> Install Vagrant from native repository.'
    sudo apt-get install -qq vagrant
    exit 0
fi

vagrant_url="https://releases.hashicorp.com/vagrant"
# Check if provided Vagrant version is available for download.
if [ -n "$install_ver" ]; then
    wget -qO - $vagrant_url 2> /dev/null | grep -qF "vagrant_$install_ver"
    if [ $? -ne 0 ]; then
        _exit "Vagrant version '$install_ver' is not available for download."
    fi
else
    install_ver=$(wget -qO - $vagrant_url 2> /dev/null | \
        grep --color=never -oP "(?<=vagrant_)\d+\.\d+\.\d+" | sort -V | tail -n 1)
    if [[ $? -ne 0 || -z "$install_ver" ]]; then
        _exit 'Fail retrieve number of latest Vagrant version.'
        # Probable fail: no internet, site is down or sort -V is unknown.
        # alternative to `sort -V` is `sort -t. -k1,1n -k2,2n -k3,3n`
    fi
fi

# Download and install Vagrant deb package.
vagrant_deb="vagrant_${install_ver}_x86_64.deb"
vagrant_sums="vagrant_${install_ver}_SHA256SUMS"

function _cleanup() {
    cd - > /dev/null
    rm -rf $vagrant_tmp 2> /dev/null
}

vagrant_tmp=$(mktemp -dq)
cd $vagrant_tmp
echo "==> Download Vagrant $install_ver DEB package."
wget -q $vagrant_url/$install_ver/$vagrant_deb
if [ $? -ne 0 ]; then
    _cleanup
    _exit "Fail download file '$vagrant_deb'."
fi
wget -q $vagrant_url/$install_ver/$vagrant_sums
if [ $? -ne 0 ]; then
    _cleanup
    _exit "Fail download file '$vagrant_sums'."
fi

# Verify downloads.
sed -n "/$vagrant_deb/p" "$vagrant_sums" | sha256sum -c > /dev/null 2>&1
if [ $? -ne 0 ]; then
    _cleanup
    _exit "File '$vagrant_deb' does not pass hash check."
fi

echo "==> Install Vagrant $install_ver package."
sudo dpkg -i $vagrant_deb
sudo apt-get install -fqq

# Clean-up.
_cleanup
