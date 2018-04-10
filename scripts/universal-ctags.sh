#!/usr/bin/env bash
# Install Universal Ctags. (https://github.com/universal-ctags/ctags)

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install Universal Ctags package - active fork of Exuberant Ctags.
If system already has Ctags program, Universal Ctags will be installed as 'exctags'.
OPTION:
    -l      Install locally for current user.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Universal Ctags installation.'
    exit ${2:-1}
}

# Execute command.
# Args:
#   $1  Run as user.
#   $2  Command.
function _eval() {
    if [ $UID -eq 0 ]; then
        sudo -iH -u $1 bash -c "$2"
    else
        bash -c "$2"
    fi
}

# Create directory.
# Args:
#   $1  User name.
#   $2  Path.
function _mkdir() {
    _eval $1 "mkdir -p $2 2> /dev/null"
    [ $? -ne 0 ] && return 1
    chown -R $1:$(id -gn $1) $2 2> /dev/null
}

# Default values.
[ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER
unctags_local=1
unctags_prex=''

# Process arguments.
while getopts ":hl" OPTION; do
    case $OPTION in
        l) unctags_local=0;;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126
[[ $unctags_local -eq 0 && $cuser = 'root' ]] && _exit 'Can not install for root user.' 126
# Check required software.
git --version > /dev/null 2>&1 || _exit 'Git is not available.' 127

# Determine path for placing Universal Ctags binaries.
unctags_location=/usr/local
[ $unctags_local -eq 0 ] && unctags_location=/home/$cuser/.local

# Check if any other Ctags packages is installed.
ctags_current=$(_eval $cuser 'ctags --version 2> /dev/null')
if [ -n "$ctags_current" ]; then
    echo -e "$ctags_current" | grep -qi 'Universal Ctags'
    [ $? -ne 0 ] && unctags_prefix='ex'
fi

# Create all required directories.
if [ $unctags_local -eq 0 ]; then
    _mkdir $cuser $unctags_location/bin || _exit 'Fail to create directory for Universal Ctags binaries.'
    _mkdir $cuser $unctags_location/share/man/man1
fi

echo '==> Install Universal Ctags from source code.'
echo '==> Install dependencies.'
sudo apt-get update -qq
sudo apt-get install -qq build-essential pkg-config automake

# Download source code.
echo '==> Download source code.'
unctags_tmp=$(mktemp -dq)
git clone -q --depth 1 https://github.com/universal-ctags/ctags.git $unctags_tmp 2> /dev/null
[ $? -ne 0 ] && _exit 'Fail to download Universal Ctags source code.'
cd $unctags_tmp > /dev/null

# Build and install.
echo '==> Build binaries from source code.'
sh autogen.sh
sed -i -e "s/VERSION='[-0-9a-zA-Z_\.]\+'/VERSION='5.8'/g" \
    -e "s/PACKAGE_VERSION='[-0-9a-zA-Z_\.]\+'/PACKAGE_VERSION='5.8'/g" \
    -e "s/PACKAGE_STRING='universal-ctags [-0-9a-zA-Z_\.]\+'/PACKAGE_STRING='universal-ctags 5.8'/g" configure
./configure --prefix=$unctags_location --program-prefix=$unctags_prefix
make --quiet
make install
if [ $unctags_local -eq 0 ]; then
    chown $cuser:$(id -gn $cuser) $unctags_location/bin/${unctags_prefix}*tags
fi

# Clean-up.
cd - > /dev/null
rm -rf $unctags_tmp

echo "Universal Ctags available as: $unctags_location/bin/${unctags_prefix}ctags"
