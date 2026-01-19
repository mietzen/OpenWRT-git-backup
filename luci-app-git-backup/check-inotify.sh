#!/bin/sh
# Check if inotify tools are available for filesystem watching

echo "=== Checking Event-Driven Options ==="
echo ""

echo "1. Checking for inotifywait (filesystem event monitoring)..."
if command -v inotifywait >/dev/null 2>&1; then
    echo "   ✓ inotifywait is available!"
    echo "   Version: $(inotifywait --help 2>&1 | head -1)"
    echo ""
    echo "   We can use inotify for true event-driven monitoring!"
else
    echo "   ✗ inotifywait not found"
    echo "   Package: inotify-tools"
    echo "   Install: opkg update && opkg install inotify-tools"
fi
echo ""

echo "2. Checking for ubus (message bus)..."
if command -v ubus >/dev/null 2>&1; then
    echo "   ✓ ubus is available"
    echo "   Testing ubus listen..."
    timeout 2 ubus list >/dev/null 2>&1 && echo "   ✓ ubus is functional" || echo "   ⚠ ubus may not be working"
else
    echo "   ✗ ubus not found (unusual for OpenWrt)"
fi
echo ""

echo "3. Current approach: Polling (checking git status every 2s)"
echo "   - Works everywhere, no dependencies"
echo "   - 2-7 second delay for backups"
echo "   - Minimal resource usage"
echo ""

if ! command -v inotifywait >/dev/null 2>&1; then
    echo "=== Recommendation ==="
    echo "Option 1: Keep polling (works now, no changes needed)"
    echo "Option 2: Install inotify-tools for true event-driven:"
    echo "   opkg update"
    echo "   opkg install inotify-tools"
    echo ""
    echo "Would you like event-driven monitoring? (requires ~30KB package)"
fi
