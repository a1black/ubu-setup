#!/usr/bin/env bash
#Install Oracle JDK if available.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Install Java Developement Kit.
OPTION:
    -r      Version of installing JDK.
    -o      Install OpenJDK package if available (default false).
    -h      Show this message.

EOF
    exit 1
}

function _exit() {
    echo "Error: $1"
    echo '       Abort JDK installation.'
    exit ${2:-1}
}

# Default values.
jdk_use_openjdk=1

# Process arguments.
while getopts ":hor:" OPTION; do
    case $OPTION in
        r) jdk_version="$OPTARG";;
        o) jdk_use_openjdk=0;;
        *) show_usage;;
    esac
done

# Check privileges.
[ $UID -ne 0 ] && _exit 'Run script with root privileges.' 126

# Validate JDK version number.
if [ -z "$jdk_version" ]; then
    _exit 'JDK version is not specified.' 2
elif ! [[ "$jdk_version" =~ ^[0-9]+$ ]]; then
    _exit 'JDK version must be a simple number: 7/8/9 etc.' 2
fi

# Add unofficial Oracle JDK PPA repository.
#grep -qi --include=*\.list -e '^deb .\+webupd8team' \
#    /etc/apt/sources.list /etc/apt/sources.list.d/*
#if [ $? -ne 0 ]; then
    echo '==> Add unofficial Oracle JDK PPA to source list.'
    sudo add-apt-repository -y ppa:webupd8team/java
    sudo apt-get update -qq
#fi

# Check JDK version availability.
apt-cache show oracle-java${jdk_version}-installer 2> /dev/null | grep -q '^Version:'
oracle_available=$?
apt-cache show openjdk-${jdk_version}-jdk 2> /dev/null | grep -q '^Version:'
openjdk_available=$?

# Installed version.
JAVA_VERSION=$(java -version 2>&1 | sed -n '/^java version/Ip' | \
    grep --color=never -oP "(?<=1\.)\d+" | head -n 1)
if [[ "$JAVA_VERSION" = "$jdk_version" ]]; then
    _exit "JDK $jdk_version is already installed."
fi

# Remove OpenJDK packages.
openjdk=$(dpkg -l openjdk-*-jre 2> /dev/null | sed -n '/^i/p' | \
    grep --color=never -oP '(?<=openjdk-)\d+')
if [ $? -eq 0 ]; then
    echo '==> Remove OpenJDK and JRE.'
    for jv in $openjdk; do
        sudo apt-get purge -qq openjdk-${jv}-jdk openjdk-${jv}-jre
    done
    sudo apt-get autoremove -qq
fi

# Remove Oracle JDK packages.
oraclejdk=$(dpkg -l oracle-java*-installer 2> /dev/null | sed -n '/^i/p' | \
    grep --color=never -oP '(?<=\soracle-java)\d+')
if [ $? -eq 0 ]; then
    echo '==> Remove Oracle JDK.'
    for jv in $oraclejdk; do
        sudo apt-get purge -qq oracle-java${jv}-installer
    done
    sudo apt-get autoremove -qq
fi

# Install JDK.
if [[ $openjdk_available -eq 0 && $jdk_use_openjdk -eq 0 ]] || [[ $openjdk_available -eq 0 && $oracle_available -ne 0 ]]; then
    echo "==> Install OpenJDK $jdk_version package."
    sudo apt-get install -qq openjdk-${jdk_version}-jdk
elif [ $oracle_available -eq 0 ]; then
    echo "==> Install Oracle JDK $jdk_version package."
    sudo apt-get install -qq oracle-java${jdk_version}-installer
else
    _exit 'Fail to locate requested version of JDK.'
fi
