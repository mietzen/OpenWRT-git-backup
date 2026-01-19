# Development Guide

This document explains the architecture and development workflow for the LuCI Git Backup plugin.

## Architecture Overview

### Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│                      LuCI Web UI                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Settings   │  │   History    │  │  Controller  │ │
│  │     Page     │  │     Page     │  │  (Actions)   │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
└─────────┼──────────────────┼──────────────────┼─────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────┐
│                    UCI Configuration                    │
│               /etc/config/git-backup                    │
└─────────────────────────┬───────────────────────────────┘
                          │
          ┌───────────────┴───────────────┐
          ▼                               ▼
┌──────────────────┐           ┌──────────────────────┐
│  CLI Interface   │           │   UCI Hook System    │
│  /usr/bin/       │           │   (on_after_apply)   │
│  git-backup      │           │                      │
└────────┬─────────┘           └──────────┬───────────┘
         │                                 │
         │         ┌───────────────────────┘
         │         │
         ▼         ▼
┌─────────────────────────────────────────────────────────┐
│              Backend Scripts Library                    │
│              /usr/lib/git-backup/                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │ common.sh│  │backup.sh │  │restore.sh│            │
│  └──────────┘  └──────────┘  └──────────┘            │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   Git Repository                        │
│                       / (.git)                          │
└─────────────────────────────────────────────────────────┘
```

### File Structure

```
luci-app-git-backup/
├── Makefile                              # OpenWRT package build file
├── README.md                             # User documentation
├── DEVELOPMENT.md                        # This file
├── install.sh                            # Manual installation script
├── uninstall.sh                          # Uninstallation script
│
├── luasrc/                               # LuCI Lua sources
│   ├── controller/
│   │   └── git-backup.lua               # Routes, menu, API endpoints
│   ├── model/cbi/git-backup/
│   │   ├── settings.lua                 # Settings form (CBI)
│   │   └── history.lua                  # History viewer (SimpleForm)
│   └── view/git-backup/
│       └── settings_footer.htm          # JavaScript for actions
│
└── root/                                 # Files to install in /
    ├── etc/
    │   ├── config/
    │   │   └── git-backup               # Default UCI configuration
    │   ├── init.d/
    │   │   └── git-backup-hook          # Init script for UCI hooks
    │   └── uci-defaults/
    │       └── 99-git-backup            # First-run setup
    ├── usr/
    │   ├── bin/
    │   │   └── git-backup               # Main CLI executable
    │   └── lib/git-backup/
    │       ├── common.sh                # Shared functions
    │       ├── backup.sh                # Backup logic
    │       ├── restore.sh               # Restore logic
    │       └── uci-hook.sh              # UCI change hook
```

## Component Details

### 1. UCI Configuration (`/etc/config/git-backup`)

The configuration uses OpenWRT's UCI (Unified Configuration Interface):

```uci
config settings 'settings'
    option enabled '0'                    # Enable/disable plugin
    option auth_type 'ssh'                # 'ssh' or 'https'
    option repo_url ''                    # Git repository URL
    option branch 'auto'                  # Branch name or 'auto' for hostname
    option ssh_key_path '/path/to/key'    # SSH private key location
    option https_username ''              # HTTPS username
    option https_token ''                 # HTTPS PAT/password
    option backup_dirs '/etc'             # Directories to backup
    option max_commits '5'                # Local commit limit
    option last_backup_time ''            # Status tracking
    option last_backup_status ''          # 'success' or 'failed'
    option last_backup_message ''         # Status message
```

Access from Lua: `uci:get("git-backup", "settings", "enabled")`
Access from Shell: `uci get git-backup.settings.enabled`

### 2. LuCI Controller (`luasrc/controller/git-backup.lua`)

**Purpose**: Defines menu structure, routes, and API endpoints

**Key Functions**:
- `index()`: Registers menu entries and routes
- `action_handler()`: Handles POST requests for actions (backup, restore, generate key, install deps)
- `get_public_key()`: Returns SSH public key content
- `get_history()`: Fetches git commit history
- `check_deps()`: Checks if git/wget are installed

**Routes**:
- `/admin/system/git-backup/settings` → Settings CBI form
- `/admin/system/git-backup/history` → History CBI form
- `/admin/system/git-backup/action` → POST endpoint for actions
- `/admin/system/git-backup/get_public_key` → GET SSH public key
- `/admin/system/git-backup/get_history` → GET commit history
- `/admin/system/git-backup/check_deps` → GET dependency status

### 3. CBI Forms

**Settings Form (`luasrc/model/cbi/git-backup/settings.lua`)**:
- Uses `Map` and `TypedSection` for UCI binding
- Dynamic content with `DummyValue` + `rawhtml`
- JavaScript actions via template footer
- `on_after_commit` hook triggers backup

**History Form (`luasrc/model/cbi/git-backup/history.lua`)**:
- Uses `SimpleForm` (not bound to UCI)
- Executes `git-backup history` and parses output
- Inline JavaScript for restore confirmation
- AJAX call to restore endpoint

### 4. Backend Scripts

**common.sh**:
- `load_config()`: Load UCI settings into shell variables
- `update_status()`: Update last backup status in UCI
- `check_git()`: Verify git is installed
- `setup_git_env()`: Configure git and authentication
- `init_git_repo()`: Initialize git at /
- `create_gitignore()`: Generate .gitignore from backup_dirs
- `has_changes()`: Check if there are uncommitted changes
- `get_current_commit()`: Get HEAD commit hash
- `get_remote_history()`: Fetch remote commit list

**backup.sh**:
1. Load config and validate
2. Setup git environment
3. Initialize repository if needed
4. Check for changes
5. Commit and push if changes exist
6. Limit local history (shallow clone)
7. Update UCI status

**restore.sh**:
1. Validate commit hash
2. Create safety backup
3. Fetch from remote
4. Verify commit exists
5. `git reset --hard <commit>`
6. Log success

**uci-hook.sh**:
- Called by UCI commit system
- Checks if backup is enabled
- Runs backup in background (non-blocking)

### 5. CLI Interface (`/usr/bin/git-backup`)

Commands:
- `backup`: Trigger backup
- `restore <commit>`: Restore to commit
- `history [count]`: Show commit history
- `status`: Show current status
- `generate-key`: Generate SSH key
- `check-deps`: Check dependencies
- `install-deps`: Install git/wget
- `help`: Show usage

### 6. UCI Hook System

**Hook Installation** (`/etc/init.d/git-backup-hook`):
- Creates `/etc/config/uci-commit.d/git-backup`
- This script runs on any UCI commit
- Triggers `/usr/lib/git-backup/uci-hook.sh`

**Hook Execution Flow**:
```
User applies config in LuCI
    ↓
UCI commit triggered
    ↓
/etc/config/uci-commit.d/git-backup executed
    ↓
/usr/lib/git-backup/uci-hook.sh runs
    ↓
Checks if enabled
    ↓
Runs /usr/bin/git-backup backup in background
```

## Development Workflow

### Setting Up Development Environment

1. **Clone Repository**:
   ```bash
   git clone https://github.com/mietzen/OpenWRT-git-backup.git
   cd OpenWRT-git-backup/luci-app-git-backup
   ```

2. **Test on OpenWRT Device**:
   ```bash
   # Transfer to router
   scp -r luci-app-git-backup root@192.168.1.1:/tmp/

   # SSH and install
   ssh root@192.168.1.1
   cd /tmp/luci-app-git-backup
   ./install.sh
   ```

3. **Make Changes**:
   - Edit files locally
   - Transfer changed files to router
   - Reload LuCI: `rm -f /tmp/luci-*cache* && /etc/init.d/uhttpd restart`

### Testing Individual Components

**Test Backend Scripts**:
```bash
# Test common functions
. /usr/lib/git-backup/common.sh
load_config
echo "Repo: $REPO_URL"

# Test backup
/usr/bin/git-backup backup

# Test history
/usr/bin/git-backup history 10

# Test restore (use real commit hash)
/usr/bin/git-backup restore abc123def
```

**Test CLI**:
```bash
git-backup status
git-backup check-deps
git-backup generate-key
```

**Test LuCI Pages**:
- Navigate to System → Git Backup
- Check browser console for JavaScript errors
- Use browser dev tools Network tab to inspect API calls

**Test UCI Hook**:
```bash
# Make a UCI change
uci set system.@system[0].hostname='test'
uci commit

# Check if backup triggered
logread | grep git-backup
```

### Debugging

**Enable Shell Debug Mode**:
```bash
# Edit scripts to add debug output
set -x  # Add to top of shell scripts
```

**Check Logs**:
```bash
# System log
logread | grep git-backup

# Live monitoring
logread -f | grep git-backup
```

**LuCI Debug**:
```bash
# Check Lua errors
logread | grep luci

# Rebuild cache
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/*
/etc/init.d/uhttpd restart
```

**Git Debug**:
```bash
# Check git status
cd /
git status
git log --oneline -10
git remote -v

# Test git operations
GIT_TRACE=1 git fetch origin
```

### Common Issues

**LuCI page not showing**:
- Clear cache: `rm -f /tmp/luci-*`
- Restart uhttpd: `/etc/init.d/uhttpd restart`
- Check file permissions
- Check Lua syntax: `lua -c /path/to/file.lua`

**Backup not triggering**:
- Check if enabled: `uci get git-backup.settings.enabled`
- Check hook exists: `ls -la /etc/config/uci-commit.d/`
- Test manually: `/usr/bin/git-backup backup`
- Check logs: `logread | grep git-backup`

**SSH key not working**:
- Check permissions: `ls -la /etc/git-backup/keys/`
- Private key should be 600
- Test SSH: `ssh -i /path/to/key git@github.com`

**HTTPS auth failing**:
- Check token is correct
- Verify credentials file: `cat /etc/git-backup/.git-credentials`
- Test clone manually with token

## Code Style Guidelines

### Lua (LuCI)
- Use tabs for indentation
- Follow LuCI naming conventions
- Use `translate()` for all user-facing strings
- Comment complex logic

### Shell Scripts
- Use `/bin/sh` (not bash) for compatibility
- Use `set -e` for error handling
- Quote variables: `"$VAR"`
- Use functions for reusability
- Comment non-obvious code

### UCI
- Use lowercase for option names
- Use underscores in option names
- Group related options

## Building as OpenWRT Package

1. **Copy to OpenWRT build tree**:
   ```bash
   cp -r luci-app-git-backup $OPENWRT_DIR/feeds/luci/applications/
   ```

2. **Update feeds**:
   ```bash
   cd $OPENWRT_DIR
   ./scripts/feeds update luci
   ./scripts/feeds install -a -p luci
   ```

3. **Configure**:
   ```bash
   make menuconfig
   # Navigate to: LuCI → Applications → luci-app-git-backup
   # Select as module (M)
   ```

4. **Build**:
   ```bash
   make package/luci-app-git-backup/compile V=s
   ```

5. **Install**:
   ```bash
   # Find built package
   find bin/ -name "luci-app-git-backup*.ipk"

   # Transfer to router and install
   scp bin/.../luci-app-git-backup_*.ipk root@router:/tmp/
   ssh root@router "opkg install /tmp/luci-app-git-backup_*.ipk"
   ```

## Contributing

When contributing:
1. Test on actual OpenWRT hardware or VM
2. Ensure UCI config is backward compatible
3. Update documentation
4. Follow existing code style
5. Test both SSH and HTTPS auth
6. Test on resource-constrained devices

## Resources

- [OpenWRT UCI Documentation](https://openwrt.org/docs/guide-user/base-system/uci)
- [LuCI Development](https://github.com/openwrt/luci/wiki)
- [OpenWRT Package Building](https://openwrt.org/docs/guide-developer/packages)
- [Git Documentation](https://git-scm.com/doc)
