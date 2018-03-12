#!/usr/bin/env bash
# Display Wi-Fi information.

if [ $EUID -ne 0 ]; then
    echo "Run script as root!"
    exit 1
elif ! iw --version > /dev/null 2>&1; then
    echo "\`iw\` is not installed."
    exit 1
fi

# Global values.
if [ $(tput colors 2> /dev/null) -ge 8 ]; then
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' BLUE='\033[0;34m' NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Properties of current Wi-fi connection.
INAME=$(iwgetid | cut -d ' ' -f 1)
SSID=$(iwgetid -r)
CHANNEL=$(iwgetid -rc)
FREQUENCY=$(iwgetid -rf | grep --color=never -o '^[0-9]\.[0-9]')
if [ -n "$SSID" ]; then
    printf "${YELLOW}Current Wi-fi connection:${NC}\n"
    printf "    ${RED}%-10s${NC} ${GREEN}%s${NC}\n" "Interface" "$INAME"
    printf "    ${RED}%-10s${NC} ${GREEN}%s${NC}\n" "SSID" "$SSID"
    printf "    ${RED}%-10s${NC} ${GREEN}%s${NC}\n" "Channel" "$CHANNEL"
    printf "    ${RED}%-10s${NC} ${GREEN}%s GHz${NC}\n" "Frequency" "$FREQUENCY"
fi

if [ -z "$INAME" ]; then
    INAME=$(iw dev | grep --color=never -oP '(?<=Interface )\w+' | head -n 1)
fi
if [ -z "$INAME" ]; then
    echo "Error: Can't found wireless network interface."
    exit 1
fi

# Get available wireless networks.
printf -- "\n----------------------------------------\n"
printf "%-20s | Quality | Channel\n" "SSID"
printf -- "----------------------------------------\n"
sudo iwlist $INAME scanning | sed -n -e '/Frequency:/p' -e '/ESSID:/p' -e '/Quality=/p' | \
    sed -E 's/\s{2,}//g' | \
while read first_line; do
    unset current_ssid current_channel current_qual
    read second_line
    read third_line
    for line in "$first_line" "$second_line" "$third_line"; do
        if [[ "$line" =~ ^ESSID:\"(.+)\" ]]; then
            current_ssid="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Frequency:.+\(Channel.([0-9]+)\) ]]; then
            current_channel="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Quality=([0-9/]+) ]]; then
            current_qual="${BASH_REMATCH[1]}"
        fi
    done
    [ -z "$current_ssid" ] && continue
    [[ "$current_ssid" = "$SSID" ]] && SC=$RED || SC=$BLUE
    [[ "$current_channel" = "$CHANNEL" ]] && CC=$RED || CC=$BLUE
    current_signal=$((${current_qual%/*}))
    if [ $current_signal -gt 50 ]; then QC=$GREEN;
    elif [ $current_signal -gt 30 ]; then QC=$YELLOW;
    else QC=$RED; fi
    printf "${SC}%-20s${NC} |  ${QC}%5s${NC}  |   ${CC}%2s${NC}  |\n" \
        "$current_ssid" "$current_qual" "$current_channel"
done
printf -- "----------------------------------------\n"

# Get channel statistic.
printf -- "\n-----------------\n"
printf "Channel | Clients\n"
printf -- "-----------------\n"
sudo iwlist $INAME scanning | sed -n '/Frequency:/p' | \
    grep --color=never -oP '(?<=Channel )\d+' | sort | uniq -c | sort -rn | \
    sed -E 's/\s{2,}//g' | \
while read stat_line; do
    if [[ "$stat_line" =~ ^([0-9]+).([0-9]+) ]]; then
        current_channel="${BASH_REMATCH[2]}"
        current_total="${BASH_REMATCH[1]}"
        [[ "$current_channel" = "$CHANNEL" ]] && CC=$RED || CC=$BLUE
        if [ $current_total -gt 5 ]; then TC=$RED;
        elif [ $current_total -gt 2 ]; then TC=$YELLOW;
        else TC=$GREEN; fi
        printf "   ${CC}%2s${NC}   |   ${TC}%s${NC}\n" "$current_channel" "$current_total"
    fi
done
printf -- "-----------------\n"
