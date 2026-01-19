#!/bin/sh
# Complete cleanup script to remove all git-backup changes from OpenWrt
# Run this to get back to a clean state before testing ipkg installation

echo "=========================================="
echo "Git Backup - Complete Cleanup Script"
echo "=========================================="
echo ""
echo "WARNING: This will remove:"
echo "  - All git-backup files"
echo "  - Git repository at /"
echo "  - UCI configuration"
echo "  - SSH keys"
echo "  - Service configuration"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# 1. Stop and disable the service
echo "1. Stopping git-backup-hook service..."
/etc/init.d/git-backup-hook stop 2>/dev/null
/etc/init.d/git-backup-hook disable 2>/dev/null
echo "   ✓ Service stopped"

# 2. Remove init script
echo "2. Removing init script..."
rm -f /etc/init.d/git-backup-hook
echo "   ✓ Init script removed"

# 3. Remove all git-backup library files
echo "3. Removing library files..."
rm -rf /usr/lib/git-backup
echo "   ✓ Library files removed"

# 4. Remove main executable
echo "4. Removing main executable..."
rm -f /usr/bin/git-backup
echo "   ✓ Executable removed"

# 5. Remove LuCI files
echo "5. Removing LuCI files..."
rm -rf /usr/lib/lua/luci/controller/git-backup.lua
rm -rf /usr/lib/lua/luci/model/cbi/git-backup
rm -rf /usr/share/rpcd/acl.d/git-backup.json
echo "   ✓ LuCI files removed"

# 6. Remove UCI config
echo "6. Removing UCI configuration..."
rm -f /etc/config/git-backup
echo "   ✓ UCI config removed"

# 7. Remove UCI commit hooks (old approach)
echo "7. Removing UCI commit hooks..."
rm -f /etc/config/uci-commit.d/git-backup
rm -f /usr/lib/git-backup/uci-hook.sh
echo "   ✓ UCI hooks removed"

# 8. Remove SSH keys and credentials
echo "8. Removing SSH keys and credentials..."
rm -rf /etc/git-backup
echo "   ✓ Keys and credentials removed"

# 9. Remove git repository at /
echo "9. Removing git repository at /..."
read -p "   Remove git repository at /? This will delete .git, .gitignore (yes/no): " confirm_git
if [ "$confirm_git" = "yes" ]; then
    cd /
    rm -rf /.git
    rm -f /.gitignore
    echo "   ✓ Git repository removed"
else
    echo "   ⊘ Git repository kept"
fi

# 10. Remove temporary files
echo "10. Removing temporary files..."
rm -f /tmp/git-backup-*
rm -f /tmp/uci-hook.log
rm -f /tmp/ubus-events-*
rm -f /var/run/git-backup-*.lock
rm -f /var/run/git-backup-*.pid
echo "   ✓ Temporary files removed"

# 11. Clear LuCI cache
echo "11. Clearing LuCI cache..."
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/*
echo "   ✓ LuCI cache cleared"

# 12. Restart uhttpd (LuCI web server)
echo "12. Restarting LuCI web server..."
/etc/init.d/uhttpd restart
echo "   ✓ LuCI restarted"

echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "Your OpenWrt is now in a clean state."
echo ""
echo "Next steps:"
echo "1. Build the ipkg package"
echo "2. Copy it to your OpenWrt device"
echo "3. Install with: opkg install luci-app-git-backup_*.ipk"
echo ""
