#!/bin/sh
# Troubleshooting script for LuCI plugin installation issues

echo "=========================================="
echo "LuCI Git Backup Plugin Diagnostics"
echo "=========================================="
echo ""

# Check if files are installed
echo "1. Checking if plugin files are installed..."
echo ""

if [ -f /usr/lib/lua/luci/controller/git-backup.lua ]; then
    echo "[OK] Controller: /usr/lib/lua/luci/controller/git-backup.lua"
else
    echo "[FAIL] Controller not found!"
fi

if [ -f /usr/lib/lua/luci/model/cbi/git-backup/settings.lua ]; then
    echo "[OK] Settings CBI: /usr/lib/lua/luci/model/cbi/git-backup/settings.lua"
else
    echo "[FAIL] Settings CBI not found!"
fi

if [ -f /usr/lib/lua/luci/model/cbi/git-backup/history.lua ]; then
    echo "[OK] History CBI: /usr/lib/lua/luci/model/cbi/git-backup/history.lua"
else
    echo "[FAIL] History CBI not found!"
fi

if [ -f /usr/bin/git-backup ]; then
    echo "[OK] CLI tool: /usr/bin/git-backup"
else
    echo "[FAIL] CLI tool not found!"
fi

echo ""
echo "2. Checking for Lua runtime and LuCI compatibility..."
echo ""

# Check for luci-compat (includes Lua and CBI support)
if opkg list-installed | grep -q "^luci-compat"; then
    echo "[OK] luci-compat is installed (includes Lua runtime for CBI)"
elif command -v lua >/dev/null 2>&1; then
    echo "[WARN] Lua is installed but luci-compat is not"
    echo "      Install luci-compat for better LuCI CBI support: opkg install luci-compat"
else
    echo "[FAIL] Lua/luci-compat is NOT installed!"
    echo ""
    echo "  The LuCI plugin requires Lua runtime for CBI forms."
    echo "  Install with: opkg update && opkg install luci-compat"
    echo "  Then restart uhttpd: /etc/init.d/uhttpd restart"
    echo ""
fi

# Check for Lua syntax errors if Lua is available
if command -v lua >/dev/null 2>&1; then
    echo ""
    echo "Checking for Lua syntax errors..."
    lua -e "package.path='/usr/lib/lua/?.lua;' .. package.path; dofile('/usr/lib/lua/luci/controller/git-backup.lua')" 2>&1
    if [ $? -eq 0 ]; then
        echo "[OK] Controller has no syntax errors"
    else
        echo "[FAIL] Controller has syntax errors (see above)"
    fi
fi

echo ""
echo "3. Checking LuCI cache..."
echo ""

if [ -f /tmp/luci-indexcache ]; then
    echo "[INFO] Index cache exists, will clear it"
    rm -f /tmp/luci-indexcache
    echo "[OK] Index cache cleared"
else
    echo "[OK] Index cache already clear"
fi

if [ -d /tmp/luci-modulecache ]; then
    echo "[INFO] Module cache exists, will clear it"
    rm -rf /tmp/luci-modulecache/*
    echo "[OK] Module cache cleared"
fi

echo ""
echo "3. Checking dependencies..."
echo ""

if command -v git >/dev/null 2>&1; then
    echo "[OK] git is installed"

    # Check for git-http (needed for HTTPS repositories)
    if opkg list-installed | grep -q "^git-http"; then
        echo "[OK] git-http is installed (HTTPS repository support)"
    else
        echo "[WARN] git-http is not installed"
        echo "      HTTPS repositories will not work without it"
        echo "      Install with: opkg install git-http ca-bundle"
    fi
else
    echo "[WARN] git is not installed - install with: opkg install git"
fi

# Check for CA certificates (needed for HTTPS)
if opkg list-installed | grep -q "^ca-bundle\|^ca-certificates"; then
    echo "[OK] CA certificates installed (SSL/TLS support)"
else
    echo "[WARN] CA certificates not installed"
    echo "      HTTPS will not work without SSL certificates"
    echo "      Install with: opkg install ca-bundle"
fi

if command -v wget >/dev/null 2>&1; then
    echo "[OK] wget is installed"
else
    echo "[WARN] wget is not installed - install with: opkg install wget"
fi

echo ""
echo "4. Checking UCI configuration..."
echo ""

if [ -f /etc/config/git-backup ]; then
    echo "[OK] UCI config exists: /etc/config/git-backup"
else
    echo "[WARN] UCI config not found, creating it..."
    cat > /etc/config/git-backup << 'EOF'
config settings 'settings'
	option enabled '0'
	option auth_type 'ssh'
	option repo_url ''
	option branch 'auto'
	option ssh_key_path '/etc/git-backup/keys/id_ed25519'
	option https_username ''
	option https_token ''
	option backup_dirs '/etc'
	option max_commits '5'
	option last_backup_time ''
	option last_backup_status ''
	option last_backup_message ''
	option git_user_name 'OpenWRT Backup'
	option git_user_email 'backup@openwrt'
EOF
    echo "[OK] UCI config created"
fi

echo ""
echo "5. Restarting web server..."
echo ""

/etc/init.d/uhttpd restart
if [ $? -eq 0 ]; then
    echo "[OK] uhttpd restarted successfully"
else
    echo "[FAIL] Failed to restart uhttpd"
fi

echo ""
echo "6. Checking if rpcd is running (for LuCI RPC)..."
echo ""

if pidof rpcd >/dev/null; then
    echo "[OK] rpcd is running"
    /etc/init.d/rpcd restart
    echo "[OK] rpcd restarted"
else
    echo "[WARN] rpcd is not running, LuCI may not work properly"
fi

echo ""
echo "=========================================="
echo "Diagnostics Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Clear your browser cache (Ctrl+Shift+Del)"
echo "  2. Try accessing: http://your-router-ip/cgi-bin/luci/admin/system/git-backup"
echo "  3. Check System menu for 'Git Backup' entry"
echo "  4. If still not visible, check logs: logread | grep luci"
echo ""
