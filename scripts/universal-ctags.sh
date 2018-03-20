#!/usr/bin/env bash
# Install Universal Ctags. (https://github.com/universal-ctags/ctags)

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Global installation of Universal Ctags package - active fork of Exuberant Ctags.
If system already has Ctags program, Universal Ctags will be installed as 'exctags'.
OPTION:
    -u      Install locally for specified user.
    -h      Show this message.

EOF
    exit 1
}

function _exit () {
    echo "Error: $1";
    echo "       Abort Universal Ctags installation."
    exit 1
}

# Default values.
cuser='root'
unctags_prex=''

# Process arguments.
while getopts ":hu:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        h) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $EUID -ne 0 && $cuser != $USER ]]; then
    _exit "Run script with root privileges or provide user for local installation."
elif [[ $cuser != 'root' ]]; then
    unctags_location=/home/$cuser/.local
else
    unctags_location=/usr/local
fi

# Check if any other Ctags packages is installed.
ctags_current=$(sudo -iH -u $cuser ctags --version 2> /dev/null)
if [ $? -eq 0 ]; then
    echo -e "$ctags_current" | grep -qi 'Universal Ctags'
    [ $? -ne 0 ] && unctags_prefix='ex'
fi

# Check if Git is installed.
git --version > /dev/null 2>&1
if ! git --version > /dev/null 2>&1; then
    _exit "Git is required to install Universal-ctags."
fi

# Build and install.
if [ ! -d "$unctags_location" ]; then
    mkdir -p $unctags_location 2> /dev/null
    [ $? -ne 0 ] && _exit "Fail to create directory for hosting Universal Ctags binary."
    chown $cuser:$(id -gn $cuser) $unctags_location
fi
echo "==> Build from source code."
# Install dependencies.
sudo apt-get update -qq
sudo apt-get install -qq build-essential pkg-config automake
# Clone source code from github.
unctags_tmp=$(mktemp -dq)
git clone -q --depth 1 https://github.com/universal-ctags/ctags.git $unctags_tmp
cd $unctags_tmp
# Build and install.
sh autogen.sh
./configure --prefix=$unctags_location --program-prefix=$unctags_prefix
make --quiet
make install
if [[ $cuser != 'root' ]]; then
    chown $cuser:$(id -gn $cuser) $unctags_location/bin/${unctags_prefix}*tags
fi

# Clean-up.
cd - > /dev/null
rm -rf $unctags_tmp
