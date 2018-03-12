#!/usr/bin/env bash
# Install version control system Git.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install version control system Git.
OPTION:
    -u      User who will recieve Git configuration files.
    -g      Gitconfig download link.
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
    echo "       Abort Git installation."
    exit 1
}

# Check if Git version is an old one.
function check_version() {
    local major=$(echo "$1" | cut -d '.' -f1)
    local minor=$(echo "$1" | cut -d '.' -f2)
    if [[ $major -lt 2 || $minor -lt 1 ]]; then
        return 1
    fi
    return 0
}

# Default values.
[ -n "$SUDO_USER" ] && cuser="$SUDO_USER" || cuser="$USER"
git_download="https://raw.githubusercontent.com/a1black/dotfiles/master/.gitconfig"

# Process arguments.
while getopts ":hDu:g:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user \"$OPTARG\".";;
        g) git_download="$OPTARG";;
        D) UBU_SETUP_DRY=1;;
        h) show_usage;;
    esac
done

# Check effective user privileges.
if [[ $EUID -ne 0 && $cuser != $USER ]]; then
    _exit "Run script with root privileges."
fi

# Delete old version of Git if installed.
git --version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    GIT_VERSION=$(git --version | grep --color=never -ioP '(?<=git version )\d+\.\d+')
    if check_version "$GIT_VERSION"; then
        _exit "Git is already installed."
    else
        echo "==> Delete old version of Git."
        _eval "sudo apt-get purge -qq git"
    fi
fi

# Get Git version in native system repository.
GIT_VERSION=$(apt-cache show git | sed -n '/^Version/{s/\w\+:\s*//g p}' | \
    head -n 1 | grep --color=never -o '^[0-9]\+\.[0-9]\+')

# Add APT repository with last stable version of git.
if ! check_version "$GIT_VERSION"; then
    echo "==> Add Git Core PPA to apt source list."
    _eval "sudo add-apt-repository -y ppa:git-core/ppa"
    _eval "sudo apt-get update -qq"
fi

echo "==> Install Git."
_eval "sudo apt-get install -qq git"

# Download `.gitconfig` configuration file.
gitconfig_file="/home/$cuser/.gitconfig"
if [[ ! -f "$gitconfig_file" ]]; then
    git_tmp=$(mktemp -q)
    echo "==> Download \`.gitconfig\` dotfile."
    if curl --version > /dev/null 2>&1; then
        _eval "curl -fsLo $git_tmp $git_download"
    else
        _eval "wget -qO - $git_download > $git_tmp"
    fi
    if [ $? -ne 0 ]; then
        echo "Fail to download \`.gitconfig\` file."
    else
        _eval "cp -f $git_tmp $gitconfig_file"
        _eval "chown $cuser:$(id -gn $cuser) $gitconfig_file"
    fi
    rm -f $git_tmp
fi

# Generating GPG key for GitHub.
cat << EOF

==> Instruction to generate GPG key.
    export GEN_GPG_USERID="user_name <user_email>"
# Generate key with args: user_id, algorithm, usage, expiration date
    gpg --quick-gen-key "\$GEN_GPG_USERID" rsa4096 sign 2020-01-01
# Add subkey: key fingerprint, algorithm, usage, expiration date
    export GEN_GPG_FPR=\$(gpg --list-secret-keys --with-colons | grep "\$GEN_GPG_USERID" -B 2 | head -n 1 | cut -d : -f 10)
    gpg --quick-addkey "\$GEN_GPG_FPR" rsa4096 encr 2020-01-01
# Export key to clipboard and paste it in GitHub web interface.
    gpg --armor --export "\$GEN_GPG_FPR" | xsel -i -b
# Add GPG key to git project.
    cd project_path
    git config user.signingkey "\$GEN_GPG_FPR"

EOF
