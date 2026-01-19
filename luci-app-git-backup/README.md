# LuCI Git Backup Plugin

Web-based configuration backup solution for OpenWRT that automatically backs up your configuration to a Git repository whenever UCI settings are changed.

## Features

- **Automatic Backups**: Triggered automatically when UCI configuration changes are applied
- **Web UI Configuration**: Easy setup through OpenWRT's LuCI interface
- **Dual Authentication**: Supports both SSH keys and HTTPS (username + PAT)
- **Backup History**: View all remote commits and restore to any point in time
- **SSH Key Management**: Generate SSH keys directly from the web interface
- **Dependency Management**: Install required packages (git, wget) from the UI
- **Storage Efficient**: Maintains only configured number of commits locally while preserving full history on remote
- **Multi-Device Support**: Each device can use its own branch based on hostname

## Installation

### Option 1: Manual Installation (Recommended for Development)

1. Copy the entire `luci-app-git-backup` directory to your OpenWRT device:
   ```bash
   scp -r luci-app-git-backup root@your-router-ip:/tmp/
   ```

2. SSH into your router and install files:
   ```bash
   ssh root@your-router-ip
   cd /tmp/luci-app-git-backup

   # Copy files to correct locations
   cp -r luasrc/* /usr/lib/lua/luci/
   cp -r root/* /

   # Make scripts executable
   chmod +x /usr/bin/git-backup
   chmod +x /usr/lib/git-backup/*.sh
   chmod +x /etc/uci-defaults/99-git-backup

   # Run uci-defaults script
   /etc/uci-defaults/99-git-backup

   # Reload LuCI
   rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*
   /etc/init.d/uhttpd restart
   ```

3. Access LuCI web interface at: **System → Git Backup**

### Option 2: Build as OpenWRT Package

1. Copy to your OpenWRT build system:
   ```bash
   cp -r luci-app-git-backup $OPENWRT_DIR/feeds/luci/applications/
   ```

2. Build the package:
   ```bash
   cd $OPENWRT_DIR
   make package/luci-app-git-backup/compile
   ```

3. Install on your router:
   ```bash
   opkg install luci-app-git-backup_*.ipk
   ```

## Configuration

### Initial Setup

1. **Install Dependencies** (if not already installed):
   - Navigate to **System → Git Backup → Settings**
   - Click "Install Dependencies" to install git and wget

2. **Configure Authentication**:

   **SSH Authentication (Recommended):**
   - Select "SSH Key" as authentication type
   - Click "Generate SSH Key"
   - Copy the displayed public key
   - Add it to your git server (GitHub: Settings → SSH and GPG keys → New SSH key)

   **HTTPS Authentication:**
   - Select "HTTPS (Username + Token)" as authentication type
   - Enter your git username
   - Enter your Personal Access Token (PAT)
     - GitHub: Settings → Developer settings → Personal access tokens → Generate new token
     - Required scopes: `repo` (full control)

3. **Configure Repository**:
   - **Repository URL**:
     - SSH: `git@github.com:username/repo.git`
     - HTTPS: `https://github.com/username/repo.git`
   - **Branch Name**: `auto` (uses hostname) or custom name
   - **Directories to Backup**: Space-separated list (default: `/etc`)
   - **Max Local Commits**: Number of commits to keep locally (default: 5)

4. **Enable Backup**:
   - Toggle "Enable Git Backup" to ON
   - Click "Save & Apply"

### Usage

#### Automatic Backups
Backups are triggered automatically whenever you apply UCI configuration changes through LuCI.

#### Manual Backup
Click "Backup Now" in the Settings page to trigger an immediate backup.

#### View History
Navigate to **System → Git Backup → Backup History** to:
- View all commits from remote repository
- See current active commit (highlighted in green)
- Restore to any previous commit

#### Restore Configuration
1. Go to **Backup History** page
2. Click "Restore" next to the desired commit
3. Confirm the restore operation
4. Reboot the device to apply changes

### CLI Usage

The plugin also provides a command-line interface:

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

## UCI Configuration

Configuration is stored in `/etc/config/git-backup`:

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

## How It Works

1. **Initialization**: Git repository is initialized at `/` (root)
2. **Selective Backup**: Only configured directories are included (via `.gitignore`)
3. **Automatic Trigger**: On UCI `apply`, changes are committed and pushed
4. **History Limiting**: Local repository keeps only `max_commits` to save flash space
5. **Remote Preservation**: Full history is always preserved on the remote server
6. **Branch Strategy**: Each device uses its own branch (based on hostname or custom name)

### Using with Existing Repositories

The plugin **works seamlessly with existing, non-empty repositories**:

- **Existing Branch**: If the remote branch already has commits, the plugin will automatically sync with it and continue from the latest commit
- **New Branch**: If using a new branch name, the plugin creates it fresh
- **Multiple Devices**: Multiple routers can safely backup to the same repository using different branches
- **Migrating from Standalone Script**: If you have an existing backup from the standalone script, just configure the same repository URL and branch name - the plugin will continue where it left off

The initialization process automatically detects and syncs with remote branches, so you never have to worry about conflicts.

## File Structure

```
/etc/config/git-backup              # UCI configuration
/etc/git-backup/                    # Data directory
  └── keys/                         # SSH keys
      ├── id_ed25519                # Private key
      └── id_ed25519.pub            # Public key
/usr/bin/git-backup                 # Main CLI executable
/usr/lib/git-backup/                # Library scripts
  ├── common.sh                     # Shared functions
  ├── backup.sh                     # Backup logic
  └── restore.sh                    # Restore logic
/usr/lib/lua/luci/
  ├── controller/git-backup.lua     # LuCI controller
  └── model/cbi/git-backup/         # CBI forms
      ├── settings.lua              # Settings page
      └── history.lua               # History page
/.git/                              # Git repository at root
/.gitignore                         # Generated ignore file
```

## Troubleshooting

### Backup Not Triggering Automatically
- Check if git-backup is enabled in Settings
- Verify repository URL is correct
- Check authentication (SSH key or HTTPS token)
- View logs: `logread | grep git-backup`

### SSH Key Not Working
- Ensure public key is added to git server
- Verify key permissions: `ls -la /etc/git-backup/keys/`
- Private key should be chmod 600

### HTTPS Authentication Failing
- Verify username is correct
- Ensure PAT has `repo` scope
- Check if token is expired
- Try regenerating token on git server

### Restore Not Working
- Ensure you're connected to the internet
- Verify git repository is initialized (run a backup first)
- Check if commit hash exists: `git-backup history`

### Can't Access LuCI Page
- Clear browser cache
- Restart uhttpd: `/etc/init.d/uhttpd restart`
- Rebuild LuCI cache: `rm -f /tmp/luci-*cache*`

## Security Considerations

- SSH private keys are stored in `/etc/git-backup/keys/` with restrictive permissions (600)
- HTTPS tokens are stored in UCI config (readable only by root)
- Git credentials file is created with 600 permissions
- All git operations run as root
- Backups include `/etc` which may contain sensitive configuration

## Contributing

Contributions are welcome! Please submit issues and pull requests to the project repository.

## License

MIT License - See LICENSE file for details

## Credits

Developed for OpenWRT community to provide easy, automated configuration backups using Git.
