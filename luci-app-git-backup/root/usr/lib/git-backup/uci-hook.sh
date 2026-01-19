#!/bin/sh
# UCI hook for git-backup
# This script is called when UCI changes are applied

# Load common functions
. /usr/lib/git-backup/common.sh

# Load configuration
load_config

# Only run if enabled
if [ "$ENABLED" != "1" ]; then
    exit 0
fi

# Run backup in background (don't block UCI apply)
nohup /usr/bin/git-backup backup >/dev/null 2>&1 &

exit 0
