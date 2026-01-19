#!/bin/sh
# Test script to verify git-backup installation after opkg install

echo "=========================================="
echo "Git Backup Installation Test"
echo "=========================================="
echo ""

ERRORS=0

# Test 1: Check main executable
echo "1. Checking main executable..."
if [ -x /usr/bin/git-backup ]; then
    echo "   ✓ /usr/bin/git-backup exists and is executable"
else
    echo "   ✗ /usr/bin/git-backup missing or not executable"
    ERRORS=$((ERRORS + 1))
fi

# Test 2: Check library files
echo "2. Checking library files..."
if [ -f /usr/lib/git-backup/common.sh ]; then
    echo "   ✓ Library files present"
else
    echo "   ✗ Library files missing"
    ERRORS=$((ERRORS + 1))
fi

# Test 3: Check init script
echo "3. Checking init script..."
if [ -f /etc/init.d/git-backup-hook ]; then
    echo "   ✓ Init script present"
    if /etc/init.d/git-backup-hook enabled; then
        echo "   ✓ Service is enabled"
    else
        echo "   ⚠ Service is not enabled (run: /etc/init.d/git-backup-hook enable)"
    fi
else
    echo "   ✗ Init script missing"
    ERRORS=$((ERRORS + 1))
fi

# Test 4: Check LuCI controller
echo "4. Checking LuCI controller..."
if [ -f /usr/lib/lua/luci/controller/git-backup.lua ]; then
    echo "   ✓ LuCI controller present"
else
    echo "   ✗ LuCI controller missing"
    ERRORS=$((ERRORS + 1))
fi

# Test 5: Check LuCI models
echo "5. Checking LuCI models..."
if [ -d /usr/lib/lua/luci/model/cbi/git-backup ]; then
    echo "   ✓ LuCI models present"
else
    echo "   ✗ LuCI models missing"
    ERRORS=$((ERRORS + 1))
fi

# Test 6: Check UCI config
echo "6. Checking UCI configuration..."
if [ -f /etc/config/git-backup ]; then
    echo "   ✓ UCI config present"
else
    echo "   ✗ UCI config missing"
    ERRORS=$((ERRORS + 1))
fi

# Test 7: Check dependencies
echo "7. Checking dependencies..."
MISSING_DEPS=""
for cmd in git wget; do
    if ! command -v $cmd >/dev/null 2>&1; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

if [ -z "$MISSING_DEPS" ]; then
    echo "   ✓ All dependencies installed"
else
    echo "   ⚠ Missing dependencies:$MISSING_DEPS"
    echo "   Run: opkg update && opkg install$MISSING_DEPS"
fi

# Test 8: Check watcher daemon
echo "8. Checking watcher daemon..."
if ps | grep -v grep | grep -q "watcher.sh"; then
    echo "   ✓ Watcher daemon is running"
else
    echo "   ⚠ Watcher daemon not running"
    echo "   Check: /etc/init.d/git-backup-hook status"
fi

# Test 9: Check LuCI access
echo "9. Checking LuCI menu entry..."
if grep -r "git-backup" /tmp/luci-indexcache 2>/dev/null | grep -q "System"; then
    echo "   ✓ LuCI menu entry found"
else
    echo "   ⚠ LuCI menu entry not in cache"
    echo "   Try: Clear browser cache and reload LuCI"
fi

echo ""
echo "=========================================="

if [ $ERRORS -eq 0 ]; then
    echo "✓ Installation successful!"
    echo ""
    echo "Next steps:"
    echo "1. Open LuCI web interface"
    echo "2. Go to: System > Git Backup"
    echo "3. Configure your repository settings"
    echo "4. Generate SSH keys or configure HTTPS"
    echo "5. Test with 'Backup Now' button"
else
    echo "✗ Installation incomplete ($ERRORS errors)"
    echo ""
    echo "Try reinstalling:"
    echo "  opkg remove luci-app-git-backup"
    echo "  opkg install /tmp/luci-app-git-backup_*.ipk"
fi

echo "=========================================="
echo ""
