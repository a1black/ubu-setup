#!/usr/bin/env bash
# Configure booting parameters of OS.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTIONS]
Configure booting paramenters of Ubuntu OS.
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

# Check privileges.
if [ $UID -ne 0 ]; then
    echo 'Error: Run script with root privileges.'
    exit 126
fi

# Disable animated boot logo.
echo '==> Disable splash image on boot screen.'
sudo sed -i.orig '/^GRUB_CMDLINE_LINUX_DEFAULT/s/\bsplash\b//g' /etc/default/grub

if lspci -nn | grep -q '\[03.\+AMD'; then
    echo '==> Fix OS freeze on AMD running machines.'
    # Fix "*ERROR* DC: Failed to blank crtc!".
    if ! grep -q '^GRUB_CMDLINE_LINUX_DEFAULT.\+amdgpu\.dc' /etc/default/grub; then
        sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/s/"\(.\+\)"/"\1 amdgpu.dc=0"/' /etc/default/grub
    fi
    # For other error see `dmesg`.
fi

#echo '==> Make Grub menu available by default.'
#sed -i '/^GRUB_HIDDEN_TIMEOUT/s/\(.\+\)/#\1/' /etc/default/grub

# Clean up and update.
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/s/\s\{2,\}/ /g' /etc/default/grub
sudo update-grub > /dev/null 2>&1

# INFO:
# To boot into TTY instead of GUI set runlevel to 3 (add 3 to GRUB_CMDLINE_LINUX_DEFAULT).
