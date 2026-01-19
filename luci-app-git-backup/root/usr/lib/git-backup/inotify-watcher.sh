#!/bin/sh
# Watch /etc/config/ using inotify for instant event-driven backups
# Requires: inotify-tools package

WATCH_DIR="/etc/config"
DEBOUNCE_TIME=5
PID_FILE="/var/run/git-backup-watcher.pid"
LAST_BACKUP_FILE="/tmp/git-backup-last-trigger"

# Check if inotifywait is available
if ! command -v inotifywait >/dev/null 2>&1; then
    logger -t git-backup-watcher "inotifywait not found, falling back to polling"
    exec /usr/lib/git-backup/config-watcher.sh
fi

# Cleanup on exit
cleanup() {
    logger -t git-backup-watcher "Stopping inotify watcher"
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup INT TERM EXIT

echo $$ > "$PID_FILE"

# Load config
. /usr/lib/git-backup/common.sh
load_config

if [ "$ENABLED" != "1" ]; then
    logger -t git-backup-watcher "Git backup is disabled, exiting"
    exit 0
fi

logger -t git-backup-watcher "Starting inotify watcher on $WATCH_DIR (debounce: ${DEBOUNCE_TIME}s)"

# Function to trigger backup with debouncing
trigger_backup() {
    local current_time=$(date +%s)
    local last_backup=0

    # Read last backup time
    if [ -f "$LAST_BACKUP_FILE" ]; then
        last_backup=$(cat "$LAST_BACKUP_FILE")
    fi

    # Check if enough time has passed (debounce)
    local time_since_last=$((current_time - last_backup))
    if [ $time_since_last -lt $DEBOUNCE_TIME ]; then
        return
    fi

    # Update last backup time
    echo "$current_time" > "$LAST_BACKUP_FILE"

    logger -t git-backup-watcher "Config file changed, triggering backup"
    /usr/bin/git-backup backup >/dev/null 2>&1 &
}

# Watch for file modifications, creates, moves in /etc/config/
# -m: monitor continuously
# -e: events to watch (modify, create, move, delete)
# -q: quiet mode
inotifywait -m -e modify,create,move,delete -q "$WATCH_DIR" 2>/dev/null | \
while read -r path event file; do
    # Ignore temporary files created by editors
    case "$file" in
        *.tmp|*.swp|*~) continue ;;
    esac

    # Ignore files that are in .gitignore (specifically git-backup runtime metadata)
    # This prevents loops: backup -> update git-backup config -> trigger -> backup -> ...
    if [ "$file" = "git-backup" ]; then
        logger -t git-backup-watcher "Ignoring change to $file (excluded in .gitignore)"
        continue
    fi

    logger -t git-backup-watcher "Detected: $event on $file"
    trigger_backup
done
