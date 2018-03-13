#!/usr/bin/env bash
# Some checks on network interfaces.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Perform same checks on network interfaces.
OPTION:
    -h      Show this message.

EOF
    exit 1
}

# Process arguments.
while getopts ":h" OPTION; do
    case $OPTION in
        h) show_usage;;
    esac
done

# Check any of network devices is up.
interfaces=$(lshw -short -quiet -class network 2> /dev/null | \
    grep --color=never -i network | sed 's/\s\{2,\}/\t/g' | cut -f 2)
echo "Network devices status:"
enabled=1
for interface in ${interfaces[@]}; do
    if [[ $(cat /sys/class/net/$interface/carrier) = 1 ]]; then
        enabled=0
        status='ON'
    else
        status='OFF'
    fi
    printf "%-10s %s\n" "$interface" "$status"
done
if [ $enabled -ne 0 ]; then
    echo "Error: All network devices are down."
    exit 1
fi

# Disable DNSSEC in case of problem with resolving domain names.
gateway=$(ip route | grep '^default' | cut -d ' ' -f 3)
if [ -z "$gateway" ]; then
    ping -q -w 1 -c 1 "$gateway" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "==> Ping to default gateway \`$gateway\` failed."
        echo "==> Disable DNSSEC."
        sudo mkdir -p /etc/systemd/resolved.conf.d
        printf '[Resolve]\nDNSSEC=no\n' | \
            sudo tee /etc/systemd/resolved.conf.d/no-dnssec.conf > /dev/null
        echo "Reboot your system for changes to take effect."
        exit 1
    fi
fi
