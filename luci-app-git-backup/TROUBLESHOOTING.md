# Troubleshooting Guide

## Plugin Not Showing in LuCI

If you've installed the plugin but don't see it in the LuCI web interface, follow these steps:

### Step 1: Run Diagnostic Script

```bash
cd /tmp/OpenWRT-git-backup-*/luci-app-git-backup
./troubleshoot.sh
```

This will check:
- If plugin files are installed correctly
- Lua syntax errors
- LuCI cache status
- Dependencies
- Web server status

### Step 2: Manual Checks

**Check if files are installed:**
```bash
ls -la /usr/lib/lua/luci/controller/git-backup.lua
ls -la /usr/lib/lua/luci/model/cbi/git-backup/
ls -la /usr/bin/git-backup
```

All files should exist. If not, run `./install.sh` again.

**Check for Lua syntax errors:**
```bash
lua -e "dofile('/usr/lib/lua/luci/controller/git-backup.lua')"
```

Should return no errors.

### Step 3: Clear LuCI Cache

```bash
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/*
rm -rf /tmp/luci-sessions/*
/etc/init.d/uhttpd restart
/etc/init.d/rpcd restart
```

### Step 4: Clear Browser Cache

Press `Ctrl + Shift + Del` in your browser and clear cache, then refresh the page.

### Step 5: Check LuCI Logs

```bash
logread | grep luci
logread | grep git-backup
```

Look for any error messages.

### Step 6: Try Direct URL

Navigate directly to: `http://your-router-ip/cgi-bin/luci/admin/system/git-backup`

If you get a "404 Not Found" error, the controller isn't loaded properly.

### Step 7: Check rpcd ACL

```bash
ls -la /usr/share/rpcd/acl.d/git-backup.json
```

If missing, the init script didn't run properly:
```bash
/etc/init.d/git-backup-hook start
```

### Common Issues

**Issue: "Lua controller present but no Lua runtime installed"**
- **Cause:** LuCI compatibility layer (luci-compat) is not installed (most common issue!)
- **Solution:**
  ```bash
  opkg update
  opkg install luci-compat
  /etc/init.d/uhttpd restart
  ```
- **Note:** `luci-compat` includes Lua 5.1 runtime and CBI support needed for this plugin
- Modern OpenWRT with JavaScript-based LuCI doesn't always include Lua/CBI by default

**Issue: "Module not found" error in logs**
- Solution: Files are in wrong location. Run `./install.sh` again.

**Issue: Plugin shows but clicking gives error**
- Solution: Lua syntax error or missing dependencies. Check logs.

**Issue: Menu entry missing**
- Solution: LuCI cache not cleared. Run Step 3 above.

**Issue: Page loads but buttons don't work**
- Solution: JavaScript errors. Check browser console (F12).

## Restore Issues

### Services Not Restarting After Restore

After a restore, the script automatically reloads:
- UCI configuration
- Network settings
- Firewall rules
- DNS/DHCP (dnsmasq)
- Cron

However, **a reboot is strongly recommended** because:
- Some services don't support hot reload
- Kernel modules may need reloading
- System-wide settings require reboot

**Always reboot after restore** for best results.

### Manual Service Restart

If you can't reboot immediately, manually restart services:

```bash
# Reload UCI configs
uci commit

# Restart core services
/etc/init.d/network restart
/etc/init.d/firewall restart
/etc/init.d/dnsmasq restart
/etc/init.d/dropbear restart  # SSH server
/etc/init.d/uhttpd restart    # Web server

# Restart any custom services you modified
/etc/init.d/your-service restart
```

### Restore Fails with "Not Found"

**Symptom:** Restore says commit not found

**Cause:** Local git repo doesn't have the commit

**Solution:**
```bash
cd /
git fetch origin <branch-name> --depth=100
git-backup restore <commit-hash>
```

## Backup Not Triggering

### Automatic Backups Not Working

**Check if enabled:**
```bash
uci get git-backup.settings.enabled
```
Should return `1`. If not:
```bash
uci set git-backup.settings.enabled='1'
uci commit git-backup
```

**Check UCI hook is installed:**
```bash
ls -la /etc/config/uci-commit.d/git-backup
```

If missing:
```bash
/etc/init.d/git-backup-hook restart
```

**Test manual backup:**
```bash
git-backup backup
```

Check for errors in output.

**Check logs:**
```bash
logread | grep git-backup
```

### Manual Backup Fails

**Error: "Git is not installed"**
```bash
opkg update
opkg install git wget

# For HTTPS repositories, also install:
opkg install git-http ca-bundle
```

**Error: "Failed to push to remote" or "HTTPS not supported"**

For HTTPS repositories, ensure git-http is installed:
```bash
opkg install git-http ca-bundle
```

Check authentication:
- **SSH:** Verify public key is added to git server with write access
- **HTTPS:** Verify username/token are correct and token has `repo` scope

Test SSH key:
```bash
ssh -i /etc/git-backup/keys/id_ed25519 git@github.com
```

Should show authentication success (even if connection closes).

**Error: "Repository URL not configured"**

Set in LuCI or via CLI:
```bash
uci set git-backup.settings.repo_url='git@github.com:user/repo.git'
uci commit git-backup
```

## Permission Issues

**Error: "Permission denied"**

Check file permissions:
```bash
# Scripts should be executable
chmod +x /usr/bin/git-backup
chmod +x /usr/lib/git-backup/*.sh

# SSH keys should be secure
chmod 600 /etc/git-backup/keys/id_ed25519
chmod 644 /etc/git-backup/keys/id_ed25519.pub
```

## Git Repository Issues

### Repository in Inconsistent State

**Symptom:** Backups fail with git errors

**Solution:** Reset git repository:
```bash
cd /
rm -rf .git
git-backup backup
```

This will reinitialize and sync with remote.

### Merge Conflicts

**Symptom:** "Merge conflict" errors

**Cause:** Multiple devices modifying same branch

**Solution:** Use separate branches per device:
```bash
uci set git-backup.settings.branch='device-name'
uci commit git-backup
```

Or force reset to remote:
```bash
cd /
git fetch origin <branch>
git reset --hard origin/<branch>
```

## Network Issues

**Backup fails intermittently**

Check network connectivity:
```bash
ping -c 3 github.com
```

Increase timeout or retry logic if on slow/unreliable connection.

## Getting Help

If issues persist:

1. **Collect debug info:**
   ```bash
   ./troubleshoot.sh > debug.log 2>&1
   git-backup status >> debug.log
   logread | grep git-backup >> debug.log
   ```

2. **Check GitHub issues:**
   https://github.com/mietzen/OpenWRT-git-backup/issues

3. **Create new issue with:**
   - OpenWRT version
   - Installation method (opkg or manual)
   - Output of `./troubleshoot.sh`
   - Relevant log entries
   - What you tried
