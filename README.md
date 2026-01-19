# OpenWRT Git Backup

A LuCI plugin that automatically backs up your OpenWRT configuration to a Git repository.

## Features

- Automatic backups triggered on UCI configuration changes
- Web interface for easy setup (System → Git Backup)
- SSH key or HTTPS authentication
- View backup history and restore previous configurations
- Multi-device support using branches

## Installation

Install via opkg:

```bash
opkg update
opkg install luci-app-git-backup
```

All dependencies (luci-compat, git, git-http, ca-bundle, wget) are installed automatically.

## Quick Start

1. Navigate to **System → Git Backup** in LuCI
2. Configure authentication (SSH key or HTTPS token)
3. Set your repository URL and branch
4. Enable backups and click "Save & Apply"

### SSH Key Authentication (Recommended)

- Click "Generate SSH Key" in the settings
- Copy the public key and add it to your Git server as a deploy key

### HTTPS Authentication

- Enter your Git username and Personal Access Token

## Usage

Backups run automatically when you apply configuration changes. You can also:

- **Manual backup**: Click "Backup Now" in settings
- **View history**: Go to Backup History page
- **Restore**: Click "Restore" next to any commit

## Command Line

```bash
git-backup backup              # Manual backup
git-backup history             # View commits
git-backup restore <hash>      # Restore configuration
git-backup status              # Show current status
```

## Configuration

Settings are stored in `/etc/config/git-backup`:

```
config settings 'settings'
    option enabled '1'
    option auth_type 'ssh'
    option repo_url 'git@github.com:user/repo.git'
    option branch 'auto'
    option backup_dirs '/etc'
    option max_commits '5'
```

## License

MIT License - See [LICENSE](LICENSE) for details
