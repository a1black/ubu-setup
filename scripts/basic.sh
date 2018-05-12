#!/usr/bin/env bash
# Script installs essential command-line tools and utilits.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install essential command-line tools and utilits.
Also scripts setup system timezone and locale.
OPTION:
    -t      Set timezone and if it's Moscow set RU locale.
    -h      Show this message.

EOF
    exit 1
}

# Default values.
timezone=Etc/UTC

while getopts ":ht:" OPTION; do
    case $OPTION in
        t) timezone="$OPTARG";;
        *) show_usage;;
    esac
done

# Validate script arguments anf privileges.
if [ $UID -ne 0 ]; then
    echo 'Error: Run script with root privileges.'
    exit 126
elif [ ! -e "/usr/share/zoneinfo/$timezone" ]; then
    echo "Error: Invalid timezone '$timezone'."
    exit 2
fi

# Check if Moscow timezone.
[[ "$timezone" =~ ^Europe/Moscow$ ]] && set_ru=0

# Set timezone.
echo '==> Set timezone.'
sudo ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
[ $? -eq 0 ] && sudo tee /etc/timezone > /dev/null <<< $timezone

# Set locales.
echo '==> Set locale.'
sudo apt-get install -qq language-pack-en
sudo locale-gen en_US
[ -n "$set_ru" ] && sudo locale-gen ru_RU ru_RU.UTF-8
LCRU='en_GB.UTF-8'      # en_GB is close to RU and keeps all in english.
sudo update-locale LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 LC_COLLATE=en_US.UTF-8
[ -n "$set_ru" ] && sudo update-locale LC_{TIME,\
ADDRESS,IDENTIFICATION,MEASUREMENT,MONETARY,NAME,NUMERIC,PAPER,TELEPHONE}=$LCRU

# Package build and destribution.
echo '==> Install essential packages.'
sudo apt-get update -qq
sudo apt-get install -qq software-properties-common build-essential pkg-config \
    cmake automake libevent-dev ca-certificates lsb-release libncurses5-dev

# Python 2 packages.
sudo apt-get install -qq python-dev python-pip python-setuptools
# Python 3 packages.
sudo apt-get install -qq python3-dev python3-pip python3-setuptools

# Network tools.
echo '==> Install network tools and applications.'
sudo apt-get install -qq net-tools traceroute nmap wget curl nfs-common ncftp

# Usefull packages.
echo '==> Install other usefull packages.'
sudo apt-get install -qq xsel htop zip unzip most dconf-editor
