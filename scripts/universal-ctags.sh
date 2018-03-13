#!/usr/bin/env bash
# Install Universal Ctags. (https://github.com/universal-ctags/ctags)

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Global installation of Universal Ctags package - active fork of Exuberant Ctags.
OPTION:
    -u      Install package locally.
    -D      Print commands, don't execute them.
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
    echo "       Abort Universal Ctags installation."
    exit 1
}

# Default values.
cuser='root'
unctags_prex=''

# Process arguments.
while getopts ":hDu:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        D) UBU_SETUP_DRY=1;;
        h) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $EUID -ne 0 && $cuser != $USER ]]; then
    _exit "Run script with root privileges or provide user for local install."
elif [[ $cuser != 'root' ]]; then
    unctags_location=/home/$cuser/.local
else
    unctags_location=/usr/local
fi

# Check if Universal Ctags is already installed.
ctags --version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    ctags --version | grep -qi 'Universal Ctags'
    [ $? -ne 0 ] && unctags_prefix='ex'
fi

# Check if Git is installed.
git --version > /dev/null 2>&1
if ! git --version > /dev/null 2>&1; then
    _exit "Git is required to install Universal-ctags."
fi

# Build and install.
echo "==> Build from source code."
# Install dependencies.
_eval "sudo apt-get install -qq build-essential pkg-config automake"
# Clone source code from github.
unctags_tmp=$(mktemp -dq)
_eval "git clone -q --depth 1 https://github.com/universal-ctags/ctags.git $unctags_tmp"
cd $unctags_tmp
# Build and install.
_eval "sh autogen.sh"
_eval "./configure --prefix=$unctags_location --program-prefix=$unctags_prefix"
_eval "make --quiet"
_eval "make install"
if [[ $cuser != 'root' ]]; then
    _eval "chown $cuser:$(id -gn $cuser) $unctags_location/bin/${unctags_prefix}*tags"
fi

# Clean-up.
cd - > /dev/null
rm -rf $unctags_tmp
