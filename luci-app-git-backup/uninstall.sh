#!/bin/sh
# Uninstallation script for luci-app-git-backup

set -e

echo "========================================"
echo "Uninstalling LuCI Git Backup Plugin"
echo "========================================"
echo ""

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

# Confirm uninstallation
echo "WARNING: This will remove the Git Backup plugin."
echo "Your backed up data on the remote repository will NOT be deleted."
echo "The local git repository at / will also be preserved."
echo ""
echo -n "Continue? [y/N]: "
read -r response

if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""

# Stop and disable service
echo "Stopping UCI hook service..."
/etc/init.d/git-backup-hook stop 2>/dev/null || true
/etc/init.d/git-backup-hook disable 2>/dev/null || true

# Remove LuCI files
echo "Removing LuCI files..."
rm -f /usr/lib/lua/luci/controller/git-backup.lua
rm -rf /usr/lib/lua/luci/model/cbi/git-backup
rm -rf /usr/lib/lua/luci/view/git-backup

# Remove system files
echo "Removing system files..."
rm -f /usr/bin/git-backup
rm -rf /usr/lib/git-backup
rm -f /etc/init.d/git-backup-hook

# Remove UCI hook
rm -f /etc/config/uci-commit.d/git-backup

# Ask about config and data
echo ""
echo -n "Remove configuration (/etc/config/git-backup)? [y/N]: "
read -r response
if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    rm -f /etc/config/git-backup
    echo "  Configuration removed"
fi

echo ""
echo -n "Remove SSH keys and data (/etc/git-backup)? [y/N]: "
read -r response
if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    rm -rf /etc/git-backup
    echo "  Data directory removed"
fi

echo ""
echo -n "Remove git repository at / (/.git)? [y/N]: "
read -r response
if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    rm -rf /.git /.gitignore
    echo "  Git repository removed"
fi

# Clear LuCI cache
echo ""
echo "Clearing LuCI cache..."
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/*
rm -rf /tmp/luci-sessions/*

# Restart web server
echo "Restarting web server..."
/etc/init.d/uhttpd restart

echo ""
echo "========================================"
echo "Uninstallation completed!"
echo "========================================"
echo ""
