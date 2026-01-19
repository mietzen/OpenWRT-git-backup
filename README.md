# OpenWRT Git Backup

Automated backup solution for OpenWRT that commits configuration changes to a Git repository through a LuCI web interface.

## Features

- **Automatic Backups**: Triggered when UCI configuration changes are applied (event-driven)
- **Web-based Configuration**: Easy setup through OpenWRT's LuCI interface
- **Dual Authentication**: SSH key or HTTPS (username + token) support
- **Backup History**: View all remote commits and restore to any point in time
- **Multi-Device Support**: Multiple routers can backup to the same repository using different branches
- **Dependency Management**: Install required packages (git, wget) directly from the web UI
- **SSH Key Management**: Generate keys and view public key from the web interface
- **CLI Support**: Full command-line interface included for advanced users
- **Storage Efficient**: Configurable local commit limit while preserving full history on remote

## Installation

There are two installation methods:

### Method 1: Quick Install (Manual)

```bash
# Download and extract
cd /tmp
wget -O luci-app-git-backup.tar.gz https://github.com/mietzen/OpenWRT-git-backup/archive/refs/heads/main.tar.gz
tar xzf luci-app-git-backup.tar.gz
cd OpenWRT-git-backup-*/luci-app-git-backup

# Install
./install.sh
```

**Note:** This method copies files directly. You will need to install dependencies (git, wget) manually using the "Install Dependencies" button in the web UI, or via command line:
```bash
opkg update && opkg install git wget
```

### Method 2: Install via opkg Package (Recommended)

Build and install as an OpenWRT package for automatic dependency management:

```bash
# See detailed instructions in luci-app-git-backup/README.md
```

When installed via opkg, dependencies (git, wget) are **automatically installed** based on package metadata.

After installation, access the plugin through **System → Git Backup** in your LuCI web interface.

## Quick Start

1. **Install Dependencies** (if using manual installation):
   - Navigate to System → Git Backup → Settings
   - If dependencies are missing, click "Install Dependencies"
   - (opkg package installations handle this automatically)

2. **Configure Authentication**:

   **Option A: SSH Key (Recommended)**
   - Select "SSH Key" as authentication type
   - Click "Generate SSH Key"
   - Copy the displayed public key
   - Add it to your git server as a deploy key with write access

   **Option B: HTTPS**
   - Select "HTTPS (Username + Token)"
   - Enter your git username
   - Enter your Personal Access Token (PAT)

3. **Configure Repository**:
   - Enter repository URL (e.g., `git@github.com:user/repo.git`)
   - Set branch name (`auto` uses hostname, or enter custom name)
   - Configure directories to backup (default: `/etc`)
   - Set maximum local commits (default: 5)

4. **Enable and Backup**:
   - Toggle "Enable Git Backup" to ON
   - Click "Save & Apply"
   - Click "Backup Now" to create first backup

## Usage

### Automatic Backups

Backups are triggered automatically whenever you apply UCI configuration changes through LuCI. No manual intervention required.

### Manual Backup

Click the "Backup Now" button in the Settings page to trigger an immediate backup.

### View History

Navigate to **System → Git Backup → Backup History** to:
- View all commits from the remote repository
- See the currently active commit
- Restore to any previous commit

### Restore Configuration

1. Go to Backup History page
2. Click "Restore" next to the desired commit
3. Confirm the restore operation
4. Reboot the device to apply changes

### Command Line Interface

The plugin includes a full CLI for advanced users and scripting:

```bash
# Perform backup
git-backup backup

# View history
git-backup history [count]

# Restore to specific commit
git-backup restore <commit-hash>

# Show current status
git-backup status

# Generate SSH key
git-backup generate-key

# Check dependencies
git-backup check-deps

# Install dependencies
git-backup install-deps
```

## Migrating from Standalone Script (v1.x)

If you previously used the standalone script version:

1. Install the LuCI plugin using the installation instructions above
2. In the plugin settings, use the **same repository URL and branch name** as your old script
3. The plugin will automatically sync with your existing backup history
4. Your old backups are preserved and the plugin continues from the latest commit
5. You can safely remove the old standalone script and service

The plugin includes all functionality of the standalone script plus a web UI and event-driven backups.

## How It Works

1. **Git Repository**: Initialized at `/` (root filesystem)
2. **Selective Backup**: Only configured directories are included via `.gitignore`
3. **Event-Driven**: UCI hook triggers backup when configuration is applied
4. **Storage Optimization**: Local repository keeps only configured number of commits to save flash space
5. **Remote Preservation**: Full history is always preserved on the remote git server
6. **Branch Strategy**: Each device uses its own branch (hostname-based or custom)

### Compatibility with Existing Repositories

The plugin works seamlessly with existing, non-empty repositories:

- **Existing Branch**: Automatically syncs with existing commits and continues from latest
- **New Branch**: Creates fresh branch if specified branch doesn't exist
- **Multiple Devices**: Multiple routers can safely backup to same repository using different branches
- **No Conflicts**: Initialization detects and syncs with remote branches automatically

## Configuration

Configuration is stored in UCI at `/etc/config/git-backup`:

```
config settings 'settings'
    option enabled '1'
    option auth_type 'ssh'
    option repo_url 'git@github.com:user/repo.git'
    option branch 'auto'
    option ssh_key_path '/etc/git-backup/keys/id_ed25519'
    option https_username ''
    option https_token ''
    option backup_dirs '/etc'
    option max_commits '5'
    option git_user_name 'OpenWRT Backup'
    option git_user_email 'backup@openwrt'
```

## Troubleshooting

### Backup Not Triggering Automatically
- Verify git-backup is enabled in Settings
- Check repository URL is correct
- Verify authentication (SSH key or HTTPS token)
- Review logs: `logread | grep git-backup`

### SSH Key Issues
- Ensure public key is added to git server with write access
- Verify key permissions: `ls -la /etc/git-backup/keys/`
- Private key should be chmod 600

### HTTPS Authentication Failing
- Verify username is correct
- Ensure PAT has `repo` scope and is not expired
- Try regenerating token on git server

### Restore Not Working
- Ensure internet connectivity
- Verify git repository is initialized (run a backup first)
- Check if commit hash exists: `git-backup history`

### LuCI Page Not Showing
- Clear LuCI cache: `rm -f /tmp/luci-*cache*`
- Restart web server: `/etc/init.d/uhttpd restart`

## Documentation

- **User Guide**: [luci-app-git-backup/README.md](luci-app-git-backup/README.md)
- **Developer Guide**: [luci-app-git-backup/DEVELOPMENT.md](luci-app-git-backup/DEVELOPMENT.md)
- **Implementation Details**: [luci-app-git-backup/IMPLEMENTATION_SUMMARY.md](luci-app-git-backup/IMPLEMENTATION_SUMMARY.md)

## Security Considerations

- SSH private keys stored in `/etc/git-backup/keys/` with restrictive permissions (600)
- HTTPS tokens stored in UCI config (readable only by root)
- Git credentials file created with 600 permissions
- All git operations run as root (appropriate for system backup)
- Backups include `/etc` which may contain sensitive configuration

## Contributing

Contributions are welcome! Please submit issues and pull requests to the project repository.

## License

MIT License - See [LICENSE](LICENSE) for details

## Credits

Developed for the OpenWRT community to provide easy, automated configuration backups using Git.
