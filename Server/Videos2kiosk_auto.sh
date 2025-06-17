#!/bin/bash

# Variablen
LOCAL_DIR="/home/USERNAME-SERVER/Videos"
REMOTE_USER="USERNAME-client"
REMOTE_HOST="networkdevicename_cli.local"
REMOTE_DIR="/home/kiosk/Videos"
PASSWORD="**********"
INTERVAL=10

# Funktion zum Kopieren einer Datei oder eines Verzeichnisses
copy_item() {
    local item=$1
    echo "Kopiere: $item"
    expect -c "
    spawn scp -r -v \"$item\" \"$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR\"
    expect {
        \"*assword\" {
            send \"$PASSWORD\r\"
            exp_continue
        }
    }
    "
}

# Funktion zum Überprüfen, ob die Datei oder das Verzeichnis unverändert ist
is_item_stable() {
    local item=$1
    local size1=$(du -sb "$item" | cut -f1)
    sleep $INTERVAL
    local size2=$(du -sb "$item" | cut -f1)
    if [ "$size1" -eq "$size2" ]; then
        echo "Item ist stabil: $item"
        return 0
    else
        echo "Item ist nicht stabil: $item"
        return 1
    fi
}

# Kopiere alle vorhandenen Dateien und Verzeichnisse
for item in "$LOCAL_DIR"/*; do
    if [ -e "$item" ]; then
        copy_item "$item"
        rm -rf "$item"
    fi
done

# Hauptschleife zum Überprüfen neuer Dateien und Verzeichnisse
while true; do
    for item in "$LOCAL_DIR"/*; do
        if [ -e "$item" ]; then
            if is_item_stable "$item"; then
                copy_item "$item"
                rm -rf "$item"
            fi
        fi
    done
    sleep $INTERVAL
done

