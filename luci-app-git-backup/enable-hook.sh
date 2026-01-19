#!/bin/sh
# Quick fix script to enable UCI hooks and fix issues

echo "Enabling git-backup UCI hook service..."
/etc/init.d/git-backup-hook enable
/etc/init.d/git-backup-hook start

echo "Verifying hook installation..."
if [ -f /etc/config/uci-commit.d/git-backup ]; then
    echo "✓ UCI commit hook is installed at /etc/config/uci-commit.d/git-backup"
else
    echo "✗ UCI commit hook is NOT installed!"
    echo "  Run: /etc/init.d/git-backup-hook start"
fi

echo ""
echo "Configuring git to disable pager..."
git config --global core.pager cat

echo ""
echo "Verifying git config..."
git config --global --list | grep -E "(user\.|core\.pager)"

echo ""
echo "Testing backup..."
/usr/bin/git-backup backup

echo ""
echo "Done! Try saving a UCI config change in LuCI to test the hook."
