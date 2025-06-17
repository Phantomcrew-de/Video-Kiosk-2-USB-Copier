#!/bin/bash

# Variablen
LOCAL_DIR="/home/USERNAME-SERVER/Videos"
ARCHIVE_NAME="videos_$(date +%Y-%m-%d).tar"
REMOTE_USER="USERNAME-client"
REMOTE_HOST="networkdevicename_cli.local"
REMOTE_DIR="/home/kiosk/Videos"
PASSWORD="**********"

# Packen der Dateien in ein tar Archiv mit Fortschritt
echo "Packen der Dateien in ein tar Archiv..."
tar -cvf $LOCAL_DIR/$ARCHIVE_NAME -C $LOCAL_DIR .

# Übertragung des Archivs mit Fortschritt
echo "Übertragung des Archivs zum Remote-Rechner..."
sshpass -p "$PASSWORD" scp -v $LOCAL_DIR/$ARCHIVE_NAME $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR

# Entpacken des Archivs auf dem Remote-Rechner und Löschen des Archivs mit Fortschritt
echo "Entpacken des Archivs auf dem Remote-Rechner..."
sshpass -p "$PASSWORD" ssh -t $REMOTE_USER@$REMOTE_HOST << EOF
echo "Wechseln in das Remote-Verzeichnis..."
cd $REMOTE_DIR
echo "Entpacken des Archivs..."
tar -xvf $ARCHIVE_NAME
echo "Löschen des Archivs..."
rm $ARCHIVE_NAME
EOF

# Löschen des lokalen Archivs
echo "Löschen des lokalen Archivs..."
rm $LOCAL_DIR/$ARCHIVE_NAME

echo "Dateien wurden erfolgreich übertragen und entpackt."

