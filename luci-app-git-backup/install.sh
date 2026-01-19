#!/bin/sh
# Installation script for luci-app-git-backup
# Run this script on your OpenWRT device to install the plugin

set -e

echo "========================================"
echo "Installing LuCI Git Backup Plugin"
echo "========================================"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing from: $SCRIPT_DIR"
echo ""

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

# Copy LuCI Lua files
echo "Installing LuCI files..."
mkdir -p /usr/lib/lua/luci/controller
mkdir -p /usr/lib/lua/luci/model/cbi/git-backup
mkdir -p /usr/lib/lua/luci/view/git-backup

cp -v "$SCRIPT_DIR/luasrc/controller/git-backup.lua" /usr/lib/lua/luci/controller/
cp -v "$SCRIPT_DIR/luasrc/model/cbi/git-backup/"*.lua /usr/lib/lua/luci/model/cbi/git-backup/
cp -v "$SCRIPT_DIR/luasrc/view/git-backup/"*.htm /usr/lib/lua/luci/view/git-backup/

# Copy root filesystem files
echo ""
echo "Installing system files..."

# UCI config
mkdir -p /etc/config
if [ ! -f /etc/config/git-backup ]; then
    cp -v "$SCRIPT_DIR/root/etc/config/git-backup" /etc/config/
    echo "  UCI config installed"
else
    echo "  UCI config already exists, skipping"
fi

# Scripts
mkdir -p /usr/lib/git-backup
cp -v "$SCRIPT_DIR/root/usr/lib/git-backup/"*.sh /usr/lib/git-backup/
chmod +x /usr/lib/git-backup/*.sh

# Main executable
mkdir -p /usr/bin
cp -v "$SCRIPT_DIR/root/usr/bin/git-backup" /usr/bin/
chmod +x /usr/bin/git-backup

# Init script for UCI hooks
mkdir -p /etc/init.d
cp -v "$SCRIPT_DIR/root/etc/init.d/git-backup-hook" /etc/init.d/
chmod +x /etc/init.d/git-backup-hook

# Enable hook service
echo ""
echo "Enabling UCI hook service..."
/etc/init.d/git-backup-hook enable
/etc/init.d/git-backup-hook start

# Run uci-defaults
if [ -f "$SCRIPT_DIR/root/etc/uci-defaults/99-git-backup" ]; then
    echo ""
    echo "Running first-time setup..."
    sh "$SCRIPT_DIR/root/etc/uci-defaults/99-git-backup"
fi

# Clear LuCI cache
echo ""
echo "Clearing LuCI cache..."
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/*
rm -rf /tmp/luci-sessions/*

# Restart web server
echo ""
echo "Restarting web server..."
/etc/init.d/uhttpd restart

echo ""
echo "========================================"
echo "Installation completed successfully!"
echo "========================================"
echo ""
echo "Access the plugin at:"
echo "  System → Git Backup"
echo ""
echo "Or use the CLI:"
echo "  git-backup --help"
echo ""
echo "Next steps:"
echo "  1. Install dependencies (git, wget)"
echo "  2. Configure your repository"
echo "  3. Generate SSH key or configure HTTPS auth"
echo "  4. Enable automatic backups"
echo ""
