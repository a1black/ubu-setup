#!/usr/bin/env bash
# Install SQLite.

if [ $UID -ne 0 ]; then
    echo 'Error: Run script with root privileges.'
    echo '       Abort SQLite installation.'
    exit 126
fi

echo '==> Install SQLite Server.'
sudo apt-get install -qq sqlite
