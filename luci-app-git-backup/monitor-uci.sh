#!/bin/sh
# Monitor UCI commits and hook execution in real-time

echo "=== Monitoring UCI Hook Activity ==="
echo ""
echo "This will monitor:"
echo "1. UCI commit hook calls"
echo "2. Git backup execution"
echo "3. File system changes to /etc/config/"
echo ""
echo "Now go to LuCI and click 'Save & Apply' on any page..."
echo "Press Ctrl+C to stop monitoring"
echo ""
echo "========================================"
echo ""

# Add logging to the hook file temporarily
HOOK_FILE="/etc/config/uci-commit.d/git-backup"
BACKUP_FILE="${HOOK_FILE}.backup"

# Backup original hook
cp "$HOOK_FILE" "$BACKUP_FILE"

# Create enhanced hook with logging
cat > "$HOOK_FILE" << 'EOF'
#!/bin/sh
# Trigger git backup on UCI commit
logger -t uci-hook "UCI commit hook triggered! Args: $*"
echo "[$(date)] UCI hook called with args: $*" >> /tmp/uci-hook.log
/usr/lib/git-backup/uci-hook.sh &
EOF
chmod +x "$HOOK_FILE"

echo "Enhanced logging enabled. Watching logs..."
echo ""

# Monitor logs in real-time
(
    tail -f /tmp/uci-hook.log 2>/dev/null &
    TAIL1=$!
    logread -f | grep -E "(uci-hook|git-backup)" &
    TAIL2=$!

    # Wait for Ctrl+C
    trap "kill $TAIL1 $TAIL2 2>/dev/null; exit" INT TERM
    wait
) &
MONITOR_PID=$!

# Wait for user interrupt
trap "
    echo ''
    echo '========================================'
    echo 'Stopping monitor...'
    kill $MONITOR_PID 2>/dev/null
    # Restore original hook
    mv '$BACKUP_FILE' '$HOOK_FILE'
    echo 'Original hook restored'
    echo ''
    echo 'Summary of captured events:'
    echo '---'
    cat /tmp/uci-hook.log 2>/dev/null || echo 'No UCI hook calls detected'
    echo '---'
    rm -f /tmp/uci-hook.log
    exit 0
" INT TERM

wait $MONITOR_PID
