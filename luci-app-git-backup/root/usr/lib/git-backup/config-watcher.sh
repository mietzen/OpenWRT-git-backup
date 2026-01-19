#!/bin/sh
# Watch for config changes and trigger backups
# This runs as a daemon and periodically checks git status

DEBOUNCE_TIME=5  # Seconds to wait after detecting changes
CHECK_INTERVAL=2  # Check every 2 seconds
LOCK_FILE="/var/run/git-backup-watcher.lock"
PID_FILE="/var/run/git-backup-watcher.pid"

# Create lock to prevent multiple instances
exec 200>"$LOCK_FILE"
flock -n 200 || {
    echo "Config watcher already running (PID: $(cat $PID_FILE 2>/dev/null))"
    exit 1
}

echo $$ > "$PID_FILE"

# Load config to check if enabled
. /usr/lib/git-backup/common.sh
load_config

if [ "$ENABLED" != "1" ]; then
    echo "Git backup is disabled, exiting watcher"
    exit 0
fi

logger -t git-backup-watcher "Starting config watcher (check every ${CHECK_INTERVAL}s, backup after ${DEBOUNCE_TIME}s idle)"

# Track state
changes_detected_at=0
backup_in_progress=0

# Cleanup on exit
cleanup() {
    logger -t git-backup-watcher "Stopping config watcher"
    rm -f "$PID_FILE" "$LOCK_FILE"
    exit 0
}
trap cleanup INT TERM EXIT

# Function to check if git repo has uncommitted changes
has_uncommitted_changes() {
    cd / || return 1
    # Update gitignore if needed
    update_gitignore_if_needed >/dev/null 2>&1
    # Check for changes
    git add -A >/dev/null 2>&1
    ! git diff --staged --quiet 2>/dev/null
}

# Main loop
while true; do
    current_time=$(date +%s)

    # Skip check if backup is in progress
    if [ $backup_in_progress -eq 1 ]; then
        sleep $CHECK_INTERVAL
        continue
    fi

    # Check for uncommitted changes
    if has_uncommitted_changes; then
        # Changes detected
        if [ $changes_detected_at -eq 0 ]; then
            # First detection
            logger -t git-backup-watcher "Config changes detected"
            changes_detected_at=$current_time
        else
            # Changes still present, check if debounce time passed
            time_since_detection=$((current_time - changes_detected_at))
            if [ $time_since_detection -ge $DEBOUNCE_TIME ]; then
                logger -t git-backup-watcher "Triggering backup (${time_since_detection}s since last change)"
                backup_in_progress=1
                (
                    /usr/bin/git-backup backup >/dev/null 2>&1
                    logger -t git-backup-watcher "Backup completed"
                ) &
                changes_detected_at=0
                # Wait a bit before resetting flag
                sleep 3
                backup_in_progress=0
            fi
        fi
    else
        # No changes - reset detection time
        if [ $changes_detected_at -ne 0 ]; then
            logger -t git-backup-watcher "Changes disappeared (likely backed up externally)"
        fi
        changes_detected_at=0
    fi

    sleep $CHECK_INTERVAL
done
