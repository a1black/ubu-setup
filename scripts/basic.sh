#!/usr/bin/env bash
# Script installs basic and essential command-line tools and utilits.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install essential command-line tools and utilits.
Also scripts setup system timezone and locale.
OPTION:
    -R      Set Moscow time and RU locale.
    -h      Show this message.

EOF
    exit 1
}

while getopts ":hR" OPTION; do
    case $OPTION in
        R) IAMRUSSIAN=1;;
        h) show_usage;;
    esac
done

# Set timezone.
echo "==> Set timezone."
[ -z "$IAMRUSSIAN" ] && timezone=UTC || timezone=Europe/Moscow
sudo ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
# Set locales.
echo "==> Set locale."
sudo apt-get install -qq language-pack-en
sudo locale-gen en_US
[ -n "$IAMRUSSIAN" ] && sudo locale-gen ru_RU ru_RU.UTF-8
LCRU='en_GB.UTF-8'      # GB close to RU and keeps all in english.
sudo update-locale LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 LC_COLLATE=en_US.UTF-8
[ -n "$IAMRUSSIAN" ] && sudo update-locale LC_{TIME,\
ADDRESS,IDENTIFICATION,MEASUREMENT,MONETARY,NAME,NUMERIC,PAPER,TELEPHONE}=$LCRU

# Package build and destribution.
echo "==> Do preparations."
sudo apt-get update -qq
sudo apt-get install -qq software-properties-common build-essential pkg-config \
    automake libevent-dev

# Network tools.
echo "==> Install network tools and applications."
sudo apt-get install -qq net-tools traceroute nmap curl nfs-common ncftp

# Usefull packages.
echo "==> Install other usefull packages."
sudo apt-get install -qq xsel htop zip unzip

# Python program language.
echo "==> Install python2 and python3 packages."
sudo apt-get install -qq python python3
echo "==> Install python module manager."
sudo apt-get install -qq python-pip python3-pip
