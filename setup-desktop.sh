#!/usr/bin/env bash
# Sequence of call to other installation scripts.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTIONS]
Script performs setup of newly installed desktop Ubuntu OS.
Script removes some of pre-installed packages (browser, gnome apps, etc)
and install essential software for day-to-day work.

OPTIONS:
    -h      Show this message.

EOF
    exit 1
}

# Process arguments.
while getopts ":h" OPTION; do
    case $OPTION in
        *) show_usage;;
    esac
done

# Global variables.
[ -n "$SUDO_USER" ] && current_user=$SUDO_USER || current_user=$USER
set_timezone=Europe/Moscow
git_dotfiles=https://github.com/a1black/dotfiles.git
vim_plug=plug

powerline_enable=0
brew_enable=0
vbox_enable=1
vagrant_enable=1
#java_version=8
php_enable=1
#pgadmin_version=3

# Check privileges.
if [ $UID -ne 0 ]; then
    echo 'Run script with root privileges.'
    exit 126
elif [ $current_user = 'root' ]; then
    echo 'Please do not use root user.'
    exit 2
fi

# Determin script relative execution path.
current_path=${BASH_SOURCE[0]%/*}
[[ -z "$current_path" || ! -d "$current_path" ]] && current_path="$PWD"

# List of instructions.
# System tweaks.
bash -- "$current_path/scripts/net-tweaks.sh" || exit 1
bash -- "$current_path/scripts/boot-tweaks.sh"
bash -- "$current_path/scripts/desktop-tweaks.sh"

# Install most neccessary packages.
bash -- "$current_path/scripts/remove-builtins.sh" || exit 1
bash -- "$current_path/scripts/basic.sh" -t $set_timezone || exit 1
bash -- "$current_path/scripts/git.sh"

# Customization.
bash -- "$current_path/scripts/dotfiles.sh" -u $current_user -c $git_dotfiles
bash -- "$current_path/scripts/powerline-font.sh"
[ "$powerline_enable" = '1' ] && bash -- "$current_path/scripts/powerline.sh"

# Command line tools.
bash -- "$current_path/scripts/vim.sh" -u $current_user -p $vim_plug -f
bash -- "$current_path/scripts/tmux.sh" -l
bash -- "$current_path/scripts/fzf.sh"
bash -- "$current_path/scripts/universal-ctags.sh" -l
bash -- "$current_path/scripts/elinks.sh"
[ "$brew_enable" = 1 ] && bash -- "$current_path/scripts/linuxbrew.sh"

# Install program language complires and interpretators.
[ -n "$java_version" ] && bash -- "$current_path/scripts/java.sh" -r $java_version
if [ "$php_enable" = 1 ]; then
    bash -- "$current_path/scripts/php.sh" -f
    bash -- "$current_path/scripts/composer.sh"
    bash -- "$current_path/scripts/phpctags.sh" -l
fi

# Install development tools.
bash -- "$current_path/scripts/lints.sh"

# Virtualization.
[ "$vbox_enable" = 1 ] && bash -- "$current_path/scripts/virtualbox.sh"
[ "$vagrant_enable" = 1 ] && bash -- "$current_path/scripts/vagrant.sh"

# GUI software.
bash -- "$current_path/scripts/chrome.sh"
bash -- "$current_path/scripts/favourite-gui-apps.sh"
[ -n "$pgadmin_version" ] && bash -- "$current_path/scripts/pgadmin.sh" -r $pgadmin_version

# Clean-up.
rm -rf /home/$current_user/{.composer,.hhvm.hhbc,.wget-hsts}
