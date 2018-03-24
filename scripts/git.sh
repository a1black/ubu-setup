#!/usr/bin/env bash
# Install version control system Git.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install version control system Git.
OPTION:
    -u      Configure Git for provided user (default current user).
    -c      Download link for Git configuration file.
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort Git installation.'
    exit ${2:-1}
}

# Check if Git version is an old one.
function check_git_version() {
    local major=$(echo "$1" | cut -d '.' -f1)
    local minor=$(echo "$1" | cut -d '.' -f2)
    ! [[ $((major)) -lt 2 || $((minor)) -lt 10 ]]
}

# Default values.
#gitconfig_download=https://raw.githubusercontent.com/a1black/dotfiles/master/.gitconfig

# Process arguments.
while getopts ":hu:c:" OPTION; do
    case $OPTION in
        u) cuser=$(id -nu "$OPTARG" 2> /dev/null);
            [ $? -ne 0 ] && _exit "Invalid user '$OPTARG'.";;
        c) gitconfig_download="$OPTARG";;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126
[ "$cuser" = 'root' ] && _exit 'Can not install Git config file for root.' 126

# Determine user.
[ -z "$cuser" ] && { [ -n "$SUDO_USER" ] && cuser=$SUDO_USER || cuser=$USER; }

# Delete old version of Git if installed.
current_version=$(git --version 2> /dev/null | \
    grep --color=never -ioP '(?<=git version )\d+\.\d+')
if [ $? -eq 0 ]; then
    if check_git_version "$current_version"; then
        _exit 'Git is already installed.'
    else
        echo '==> Delete old version of Git.'
        sudo apt-get purge -qq git
    fi
fi

# Get Git version in native system repository.
#repo_version=$(apt-cache show git 2> /dev/null | \
#    sed -n '/^Version:/{s/\w\+:\s*//g p}' | \
#    head -n 1 | grep --color=never -o '^[0-9]\+\.[0-9]\+')
# Add APT repository with last stable version of git.
#if ! check_git_version "$repo_version"; then
    echo '==> Add Git Core PPA to APT source list.'
    sudo add-apt-repository -y ppa:git-core/ppa
    sudo apt-get update -qq
#fi

echo '==> Install Git.'
sudo apt-get install -qq git

# Download '.gitconfig' configuration file.
gitconfig_file=/home/$cuser/.gitconfig
if [[ $cuser != 'root' && -n "$gitconfig_download" ]]; then
    echo "==> Download '.gitconfig' file."
    gitconfig_tmp=$(mktemp -q)
    wget -qO - $gitconfig_download > $gitconfig_tmp 2> /dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Fail to download '.gitconfig' file."
        rm -f $gitconfig_tmp 2> /dev/null
    else
        mv -f $gitconfig_tmp $gitconfig_file
        chown $cuser:$(id -gn $cuser) $gitconfig_file
        chmod 644 $gitconfig_file
    fi
fi

# Instruction on generating GPG key for GitHub.
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
