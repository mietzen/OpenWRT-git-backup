#!/bin/bash
# Test package structure before building

set -e

PKG_DIR="luci-app-git-backup"
ERRORS=0

echo "=========================================="
echo "Package Structure Test"
echo "=========================================="
echo ""

# Test 1: Check Makefile exists
echo "1. Checking Makefile..."
if [ -f "$PKG_DIR/Makefile" ]; then
    echo "   ✓ Makefile exists"
else
    echo "   ✗ Makefile missing"
    ERRORS=$((ERRORS + 1))
fi

# Test 2: Check root directory structure
echo "2. Checking root directory..."
REQUIRED_FILES=(
    "root/usr/bin/git-backup"
    "root/etc/init.d/git-backup-hook"
    "root/usr/lib/git-backup/common.sh"
    "root/usr/lib/git-backup/backup.sh"
    "root/usr/lib/git-backup/config-watcher.sh"
    "root/usr/lib/git-backup/inotify-watcher.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PKG_DIR/$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ✗ $file missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Test 3: Check LuCI files
echo "3. Checking LuCI files..."
LUCI_FILES=(
    "luasrc/controller/git-backup.lua"
    "luasrc/model/cbi/git-backup/settings.lua"
    "luasrc/model/cbi/git-backup/history.lua"
)

for file in "${LUCI_FILES[@]}"; do
    if [ -f "$PKG_DIR/$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ✗ $file missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Test 4: Check executables are executable
echo "4. Checking file permissions..."
EXEC_FILES=(
    "root/usr/bin/git-backup"
    "root/etc/init.d/git-backup-hook"
    "root/usr/lib/git-backup/common.sh"
    "root/usr/lib/git-backup/backup.sh"
    "root/usr/lib/git-backup/config-watcher.sh"
    "root/usr/lib/git-backup/inotify-watcher.sh"
)

for file in "${EXEC_FILES[@]}"; do
    if [ -x "$PKG_DIR/$file" ]; then
        echo "   ✓ $file is executable"
    else
        echo "   ⚠ $file not executable (will be fixed in build)"
    fi
done

# Test 5: Check for shell script errors
echo "5. Checking shell scripts for syntax..."
SHELL_SCRIPTS=$(find "$PKG_DIR/root" -type f -name "*.sh" -o -name "git-backup")

for script in $SHELL_SCRIPTS; do
    if bash -n "$script" 2>/dev/null; then
        echo "   ✓ $(basename $script)"
    else
        echo "   ✗ $(basename $script) has syntax errors"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "=========================================="

if [ $ERRORS -eq 0 ]; then
    echo "✓ All tests passed!"
    echo ""
    echo "Ready to build package:"
    echo "  make docker-build  (Mac/Windows)"
    echo "  make build        (Linux)"
else
    echo "✗ $ERRORS test(s) failed"
    echo ""
    echo "Fix errors before building"
fi

echo "=========================================="
echo ""

exit $ERRORS
