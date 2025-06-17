#!/bin/bash

VIDEO_LIST_FILE="/home/kiosk/Downloads/selected_videos.txt"
VIDEO_DIR="/home/kiosk/Kiosk"
USB_MOUNT_POINT=""
USB_DEVICE=""
LOG_FILE="/home/kiosk/copy_videos.log"
SUCCESS_SOUND="/home/kiosk/success.wav"  # Pfad zur WAV-Datei

# Funktion, um das zuletzt angeschlossene Laufwerk zu finden
find_latest_usb() {
    latest_usb=$(ls -t /media/kiosk/ | head -n 1)
    if [ -n "$latest_usb" ]; then
        echo "/media/kiosk/$latest_usb"
    else
        echo ""
    fi
}

# Funktion, um das zugehörige Gerät des USB-Laufwerks zu finden
find_usb_device() {
    mount_point=$1
    device=$(df "$mount_point" | tail -1 | awk '{print $1}')
    echo "$device"
}

# Funktion, um Chromium im Kiosk-Modus zu starten
start_chromium_kiosk() {
    /usr/bin/flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chromium --file-forwarding org.chromium.Chromium @@u %U @@ --kiosk file:///home/kiosk/Kiosk/dwvid.html --overscroll-history-navigation=0 &
    chromium_pid=$!
    echo "Chromium gestartet mit PID: $chromium_pid" | tee -a "$LOG_FILE"
}

# Funktion, um den Ladebalken zu starten
start_progress_bar() {
    yad --progress --title="Kopiere Videos" --percentage=0 --no-buttons --on-top --width=400 --height=100 --center \
        --text="Kopiere Dateien..." --pulsate --no-focus --auto-kill & echo $! > /tmp/progress_pid
}

# Funktion, um den Ladebalken zu aktualisieren
update_progress_bar() {
    local percentage=$1
    local text=$2
    echo "$percentage"
    echo "# $text" | tee /proc/$(cat /tmp/progress_pid)/fd/1
}

# Funktion, um den Ladebalken zu schließen
close_progress_bar() {
    if [ -f /tmp/progress_pid ]; then
        kill "$(cat /tmp/progress_pid)"
        rm /tmp/progress_pid
    fi
}

# Funktion, um das USB-Laufwerk auszuwerfen
eject_usb() {
    if [ -n "$USB_DEVICE" ]; then
        udisksctl unmount -b "$USB_DEVICE" && udisksctl power-off -b "$USB_DEVICE"
        if [ $? -eq 0 ]; then
            echo "$(date) - USB-Laufwerk erfolgreich ausgeworfen." | tee -a "$LOG_FILE"
            return 0
        else
            echo "$(date) - Fehler beim Auswerfen des USB-Laufwerks." | tee -a "$LOG_FILE"
            return 1
        fi
    fi
}

# Funktion, um eine Benachrichtigung anzuzeigen, wenn kein USB-Stick angeschlossen ist
notify_no_usb() {
    yad --text="Bitte schließen Sie einen USB-Stick an." --button=Abbrechen:1 --on-top --width=400 --height=100 --center &
    NOTIFY_PID=$!

    while true; do
        USB_MOUNT_POINT=$(find_latest_usb)
        if [ -n "$USB_MOUNT_POINT" ]; then
            echo "$(date) - USB-Laufwerk gefunden: $USB_MOUNT_POINT" | tee -a "$LOG_FILE"
            kill $NOTIFY_PID
            return 0
        fi
        sleep 2
    done &
    WAIT_PID=$!
    wait $NOTIFY_PID

    if [ $? -eq 1 ]; then
        echo "$(date) - Kopiervorgang abgebrochen." | tee -a "$LOG_FILE"
        rm -f "$VIDEO_LIST_FILE"
        kill $WAIT_PID
        return 1
    fi
}

# Funktion, um Videodateien zu kopieren
copy_videos() {
    USB_MOUNT_POINT=$(find_latest_usb)
    if [ -z "$USB_MOUNT_POINT" ]; then
        echo "$(date) - Kein USB-Laufwerk gefunden." | tee -a "$LOG_FILE"
        if notify_no_usb; then
            return 1
        fi
    fi

    USB_DEVICE=$(find_usb_device "$USB_MOUNT_POINT")
    if [ -z "$USB_DEVICE" ]; then
        echo "$(date) - Konnte das USB-Gerät nicht ermitteln." | tee -a "$LOG_FILE"
        return 1
    fi

    echo "$(date) - USB-Laufwerk gefunden: $USB_MOUNT_POINT ($USB_DEVICE)" | tee -a "$LOG_FILE"

    success=true
    total_files=$(wc -l < "$VIDEO_LIST_FILE")
    current_file=0

    start_progress_bar

    while IFS= read -r video_file || [ -n "$video_file" ]; do
        current_file=$((current_file + 1))
        full_video_path="$VIDEO_DIR/$video_file"
        percentage=$((current_file * 80 / total_files))
        update_progress_bar "$percentage" "Verarbeite Datei: $full_video_path"
        
        if [ -f "$full_video_path" ]; then
            cp "$full_video_path" "$USB_MOUNT_POINT"
            if [ $? -eq 0 ]; then
                echo "$(date) - $full_video_path wurde erfolgreich kopiert." | tee -a "$LOG_FILE"
            else
                echo "$(date) - Fehler beim Kopieren von $full_video_path." | tee -a "$LOG_FILE"
                success=false
            fi
        else
            echo "$(date) - $full_video_path existiert nicht." | tee -a "$LOG_FILE"
            success=false
        fi
    done < "$VIDEO_LIST_FILE"

    if $success; then
        echo "$(date) - Alle Dateien wurden kopiert. Lösche die Liste der ausgewählten Videodateien." | tee -a "$LOG_FILE"
        rm "$VIDEO_LIST_FILE"
        if [ $? -eq 0 ]; then
            echo "$(date) - Die Liste der ausgewählten Videodateien wurde gelöscht." | tee -a "$LOG_FILE"
            update_progress_bar 90 "USB-Laufwerk auswerfen..."
            eject_usb  # USB-Laufwerk auswerfen
            if [ $? -eq 0 ]; then
                update_progress_bar 100 "Kopieren abgeschlossen."
                aplay "$SUCCESS_SOUND"  # Spiele den Erfolgston ab
            fi
        else
            echo "$(date) - Fehler beim Löschen der Liste der ausgewählten Videodateien." | tee -a "$LOG_FILE"
        fi
    else
        echo "$(date) - Fehler beim Kopieren der Videodateien." | tee -a "$LOG_FILE"
    fi

    close_progress_bar
}

# Funktion, um zu prüfen, ob die Videodateiliste existiert und dann zu kopieren
check_and_copy_loop() {
    if [ -f "$VIDEO_LIST_FILE" ]; then
        echo "$(date) - Videodateiliste gefunden. Starte Kopiervorgang..." | tee -a "$LOG_FILE"
        
        # List the contents of the video list file for debugging
        echo "Inhalt der Videodateiliste:" | tee -a "$LOG_FILE"
        cat "$VIDEO_LIST_FILE" | tee -a "$LOG_FILE"

        copy_videos
    else
        echo "$(date) - Warten auf Videodateiliste..." | tee -a "$LOG_FILE"
    fi
}

# Starten von Chromium im Kiosk-Modus
start_chromium_kiosk

# Prüfen und Kopieren ohne Hintergrundprozess
while true; do
    check_and_copy_loop
    sleep 5
done
