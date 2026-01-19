#!/bin/sh
# Listen to ubus events and trigger backups on config changes
# This is event-driven, not polling - much more efficient!

PID_FILE="/var/run/git-backup-watcher.pid"
DEBOUNCE_TIME=5
LAST_BACKUP_FILE="/tmp/git-backup-last-trigger"

# Cleanup on exit
cleanup() {
    logger -t git-backup-watcher "Stopping ubus listener"
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup INT TERM EXIT

# Create PID file
echo $$ > "$PID_FILE"

# Load config to check if enabled
. /usr/lib/git-backup/common.sh
load_config

if [ "$ENABLED" != "1" ]; then
    logger -t git-backup-watcher "Git backup is disabled, exiting"
    exit 0
fi

logger -t git-backup-watcher "Starting ubus event listener (debounce: ${DEBOUNCE_TIME}s)"

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
        logger -t git-backup-watcher "Backup triggered but debounced (${time_since_last}s < ${DEBOUNCE_TIME}s)"
        return
    fi

    # Update last backup time
    echo "$current_time" > "$LAST_BACKUP_FILE"

    logger -t git-backup-watcher "Config change detected via ubus, triggering backup"
    /usr/bin/git-backup backup >/dev/null 2>&1 &
}

# Listen for ubus events
# LuCI emits events when committing configs
ubus listen | while read -r line; do
    # Check for UCI-related events
    case "$line" in
        *uci.commit*|*service.event*|*reload_config*)
            trigger_backup
            ;;
    esac
done
