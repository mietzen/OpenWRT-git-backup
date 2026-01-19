#!/bin/sh
# Diagnose UCI hook setup

echo "=== UCI Hook Diagnostic ==="
echo ""

echo "1. Checking if git-backup-hook service is enabled..."
if /etc/init.d/git-backup-hook enabled; then
    echo "   ✓ Service is enabled"
else
    echo "   ✗ Service is NOT enabled"
    echo "   Run: /etc/init.d/git-backup-hook enable"
fi
echo ""

echo "2. Checking if git-backup-hook init script exists..."
if [ -f /etc/init.d/git-backup-hook ]; then
    echo "   ✓ Init script exists: /etc/init.d/git-backup-hook"
    ls -l /etc/init.d/git-backup-hook
else
    echo "   ✗ Init script NOT found"
fi
echo ""

echo "3. Checking UCI commit hook directory..."
if [ -d /etc/config/uci-commit.d ]; then
    echo "   ✓ Directory exists: /etc/config/uci-commit.d"
    echo "   Contents:"
    ls -la /etc/config/uci-commit.d/
else
    echo "   ✗ Directory does NOT exist: /etc/config/uci-commit.d"
    echo "   Creating it..."
    mkdir -p /etc/config/uci-commit.d
fi
echo ""

echo "4. Checking git-backup hook file..."
if [ -f /etc/config/uci-commit.d/git-backup ]; then
    echo "   ✓ Hook file exists: /etc/config/uci-commit.d/git-backup"
    ls -l /etc/config/uci-commit.d/git-backup
    echo "   Contents:"
    cat /etc/config/uci-commit.d/git-backup
else
    echo "   ✗ Hook file NOT found: /etc/config/uci-commit.d/git-backup"
    echo "   This is why automatic backups don't work!"
fi
echo ""

echo "5. Checking UCI hook script..."
if [ -f /usr/lib/git-backup/uci-hook.sh ]; then
    echo "   ✓ UCI hook script exists: /usr/lib/git-backup/uci-hook.sh"
    ls -l /usr/lib/git-backup/uci-hook.sh
else
    echo "   ✗ UCI hook script NOT found"
fi
echo ""

echo "6. Testing hook manually..."
if [ -f /etc/config/uci-commit.d/git-backup ]; then
    echo "   Running the hook directly..."
    /etc/config/uci-commit.d/git-backup
    echo "   Check if backup was triggered (wait 2 seconds)..."
    sleep 2
    logread | tail -20 | grep git-backup || echo "   No git-backup logs found"
else
    echo "   Cannot test - hook file doesn't exist"
fi
echo ""

echo "=== Recommended Fix ==="
if [ ! -f /etc/config/uci-commit.d/git-backup ]; then
    echo "Run: /etc/init.d/git-backup-hook start"
fi
