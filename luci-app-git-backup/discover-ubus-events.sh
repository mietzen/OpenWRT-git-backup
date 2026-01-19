#!/bin/sh
# Discover what ubus events are emitted when LuCI saves config

echo "=== Discovering Ubus Events ==="
echo ""
echo "This script will listen to ALL ubus events."
echo "Now go to LuCI and click 'Save & Apply' on any page."
echo "We'll capture what events are emitted."
echo ""
echo "Press Ctrl+C when done."
echo ""
echo "========================================"
echo ""

# Create timestamped log
LOG_FILE="/tmp/ubus-events-$(date +%s).log"

echo "Logging to: $LOG_FILE"
echo ""

# Listen to all ubus events with timestamps
ubus listen | while read -r line; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $line" | tee -a "$LOG_FILE"
done

echo ""
echo "Events saved to: $LOG_FILE"
