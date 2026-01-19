# OpenWRT Git Backup

Automated backup service for OpenWRT that commits configuration changes to a Git repository.

## 🆕 LuCI Plugin (Recommended)

**New!** We now offer a web-based LuCI plugin with automatic backups on configuration changes!

### Features
- ✅ **Automatic backups** when UCI settings change (no more periodic polling)
- ✅ **Web UI** for easy configuration
- ✅ **SSH or HTTPS** authentication support
- ✅ **Backup history** viewer with restore functionality
- ✅ **SSH key generation** from the web interface
- ✅ **Dependency management** (install git/wget from UI)

### Quick Install

```bash
# Download and install the plugin
cd /tmp
wget -O luci-app-git-backup.tar.gz https://github.com/mietzen/OpenWRT-git-backup/archive/refs/heads/main.tar.gz
tar xzf luci-app-git-backup.tar.gz
cd OpenWRT-git-backup-*/luci-app-git-backup
./install.sh
```

Then access **System → Git Backup** in your LuCI web interface!

📖 **Full documentation**: [luci-app-git-backup/README.md](luci-app-git-backup/README.md)

---

## Standalone Script (Legacy)

The original standalone service is still available for users who prefer a CLI-only approach.

### Prerequisites

```bash
opkg update
opkg install git wget
```

## Installation

1. Download the backup script and service file:

```bash
mkdir -p /usr/local/bin/
wget https://raw.githubusercontent.com/mietzen/OpenWRT-git-backup/main/git_backup -O /usr/local/bin/git_backup
wget https://raw.githubusercontent.com/mietzen/OpenWRT-git-backup/main/S99git_backup -O /etc/rc.d/S99git_backup
chmod +x /usr/local/bin/git_backup
chmod +x /etc/rc.d/S99git_backup
```

2. Start the service (this will generate an SSH key on first run):

```bash
/etc/rc.d/S99git_backup start
```

3. Check the log for the generated SSH public key:

```bash
cat /var/log/git_backup.log
```

4. Add the public key as a deploy key to your GitHub repository:
   - Go to your repository → Settings → Deploy keys
   - Add the key with **write access** enabled

5. Restart the service:

```bash
/etc/rc.d/S99git_backup restart
```

6. Enable the service to start on boot:

```bash
/etc/rc.d/S99git_backup enable
```

## Configuration

Edit `/usr/local/bin/git_backup` to customize:
- `REPO_URL`: Your GitHub repository URL
- `INTERVAL`: Backup interval in seconds (default: 300)
- `MAX_COMMITS`: Maximum number of commits to keep in history (default: 5)

## Features

- **Automatic History Limiting**: The script automatically limits the git history to the last 5 commits to save storage space on the device
- **Space Optimization**: After each backup, old commits beyond the limit are pruned and garbage collected to free up disk space
- **Continuous Backup**: Monitors configuration changes and commits them at regular intervals

## Monitoring

View logs:
```bash
tail -f /var/log/git_backup.log
```

Check service status:
```bash
/etc/rc.d/git_backup status
```

---

## Comparison: LuCI Plugin vs Standalone Script

| Feature | LuCI Plugin | Standalone Script |
|---------|-------------|-------------------|
| **Configuration** | Web UI | Edit script file |
| **Trigger** | On UCI changes | Periodic (5 min) |
| **Auth Types** | SSH + HTTPS | SSH only |
| **Backup History** | Web UI viewer | Git CLI only |
| **Restore** | One-click from UI | Git CLI only |
| **Dependencies** | Auto-install from UI | Manual install |
| **SSH Key Gen** | From web UI | Manual CLI |
| **Resource Usage** | Event-driven (lower) | Polling (higher) |

**Recommendation**: Use the **LuCI plugin** for better user experience and automatic event-driven backups.

## License

MIT License - See [LICENSE](LICENSE) for details
