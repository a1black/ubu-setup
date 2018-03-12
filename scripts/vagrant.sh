#!/usr/bin/env bash
# Install Vagrant package.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install latest available version of provisioning tool Vagrant.
OPTION:
    -r      Install specific version of Vagrant.
    -D      Print command, don't execute them.
    -h      Show this message.

EOF
    exit 1
}

function _eval() {
    echo "$1"; [ -z "$UBU_SETUP_DRY" ] && eval "$1";
    return $?
}
function _exit () {
    echo "Error: $1";
    echo "       Abort Vagrant installation."
    exit 1
}

# Process arguments.
while getopts ":hDr:" OPTION; do
    case $OPTION in
        r) install_ver="$OPTARG";;
        D) UBU_SETUP_DRY=1;;
        h) show_usage;;
    esac
done

# Check user provided version number.
if [ -n "$install_ver" ] && ! [[ "$install_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    _exit "Invalid version number \"$install_ver\"."
fi

# Check if Vagrant is already installed.
if vagrant --version > /dev/null 2>&1; then
    VAG_VERSION=$(vagrant --version | cut -d ' ' -f 2)
    _exit "Vagrant is already installed."
fi

# Get Vagrant version in system native repository.
VAG_VERSION=$(apt-cache show vagrant | sed -n '/^Version:/{s/\w\+:\s*//g p}' | \
    head -n 1 | grep --color=never -oE "^[0-9]+\.[0-9]+\.[0-9]+")

if [ "$install_ver" = "$VAG_VERSION" ]; then
    echo "==> Install Vagrant from native repository."
    _eval "sudo apt-get install -qq vagrant"
    exit 0
fi

vagrant_url="https://releases.hashicorp.com/vagrant"
# Check if provided Vagrant version is available for download.
if [ -n "$install_ver" ]; then
    wget -qO - "$vagrant_url" | grep -qF "vagrant_$install_ver"
    if [ $? -ne 0 ]; then
        _exit "Vagrant version \"$install_ver\" is not available for download."
    fi
else
    install_ver=$(wget -qO - "$vagrant_url" | \
        grep --color=never -oP "(?<=vagrant_)\d+\.\d+\.\d+" | sort -V | tail -n 1)
    if [ $? -ne 0 ]; then
        _exit "Fail retrieve number of latest Vagrant version."
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
_eval "wget -q $vagrant_url/$install_ver/$vagrant_deb"
if [ $? -ne 0 ]; then
    _cleanup
    _exit "Fail download file \"$vagrant_deb\"."
fi
_eval "wget -q $vagrant_url/$install_ver/$vagrant_sums"
if [ $? -ne 0 ]; then
    _cleanup
    _exit "Fail download file \"$vagrant_sums\"."
fi

# Verify downloads.
sed -n "/$vagrant_deb/p" "$vagrant_sums" | sha256sum -c > /dev/null 2>&1
if [ $? -ne 0 ]; then
    _cleanup
    _exit "File \"$vagrant_deb\" does not pass hash check."
fi

echo "==> Install Vagrant $install_ver package."
_eval "sudo dpkg -i $vagrant_deb"
_eval "sudo apt-get install -fqq"

# Clean-up.
_cleanup
