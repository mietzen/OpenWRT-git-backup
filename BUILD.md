# Building luci-app-git-backup

This guide explains how to build the IPK package for installation on OpenWrt.

## Prerequisites

### For Mac/Windows Users (Docker Method - Recommended)
- Docker Desktop installed and running
- Make (optional, for convenience)

### For Linux Users (Native Build)
- `ar` (from binutils)
- `tar`, `gzip`
- `bash`

## Quick Start

### Mac/Windows (Docker)

```bash
# Option 1: Using make
make docker-build

# Option 2: Direct script
./docker-build.sh
```

### Linux (Native)

```bash
# Option 1: Using make
make build

# Option 2: Direct script
./build-package.sh
```

## Build Output

The build creates:
```
packages/
└── luci-app-git-backup_1.0.0-1_all.ipk
```

## Installation on OpenWrt

### Step 1: Copy Package to OpenWrt

```bash
# Replace <openwrt-ip> with your device's IP
scp packages/luci-app-git-backup_*.ipk root@<openwrt-ip>:/tmp/
```

### Step 2: Install Package

```bash
# SSH to your OpenWrt device
ssh root@<openwrt-ip>

# Install the package
opkg install /tmp/luci-app-git-backup_*.ipk
```

### Step 3: Verify Installation

```bash
# Copy test script to OpenWrt
scp test-install.sh root@<openwrt-ip>:/tmp/

# Run on OpenWrt
ssh root@<openwrt-ip>
chmod +x /tmp/test-install.sh
/tmp/test-install.sh
```

## Clean Installation (Remove Previous Version)

If you previously installed git-backup manually, clean it first:

```bash
# On your OpenWrt device
cd /tmp
git clone https://github.com/mietzen/OpenWRT-git-backup.git
cd OpenWRT-git-backup
git checkout claude/luci-plugin-hooks-icJ1I
cd luci-app-git-backup

# Run cleanup
chmod +x cleanup.sh
./cleanup.sh
```

Then proceed with the package installation above.

## Development Workflow

### 1. Make Changes

Edit files in `luci-app-git-backup/`

### 2. Test Structure

```bash
make test
```

### 3. Build Package

```bash
make docker-build  # Mac/Windows
# or
make build        # Linux
```

### 4. Install and Test

```bash
# Copy to OpenWrt
scp packages/luci-app-git-backup_*.ipk root@<openwrt-ip>:/tmp/

# On OpenWrt
ssh root@<openwrt-ip>
opkg remove luci-app-git-backup  # If upgrading
opkg install /tmp/luci-app-git-backup_*.ipk

# Verify
/tmp/test-install.sh
```

## Package Contents

The IPK package includes:

### Executables
- `/usr/bin/git-backup` - Main CLI tool

### Libraries
- `/usr/lib/git-backup/common.sh` - Shared functions
- `/usr/lib/git-backup/backup.sh` - Backup logic
- `/usr/lib/git-backup/restore.sh` - Restore logic
- `/usr/lib/git-backup/config-watcher.sh` - Polling watcher
- `/usr/lib/git-backup/inotify-watcher.sh` - Event-driven watcher (requires inotify-tools)

### LuCI Integration
- `/usr/lib/lua/luci/controller/git-backup.lua` - Controller
- `/usr/lib/lua/luci/model/cbi/git-backup/settings.lua` - Settings form
- `/usr/lib/lua/luci/model/cbi/git-backup/history.lua` - History viewer

### Service
- `/etc/init.d/git-backup-hook` - Procd service

### Configuration
- `/etc/config/git-backup` - UCI configuration template

## Dependencies

The package depends on:
- `luci-compat` - LuCI compatibility layer
- `git` - Git version control
- `git-http` - Git HTTPS support
- `ca-bundle` - SSL certificates
- `wget` - Download tool
- `luci-base` - LuCI base system

Optional (for instant event-driven backups):
- `inotify-tools` - Filesystem event monitoring

## Post-Installation

After installation, the package automatically:
1. Enables the `git-backup-hook` service
2. Starts the config watcher daemon
3. Clears LuCI cache
4. Restarts uhttpd (LuCI web server)

Access the web interface at: **System → Git Backup**

## Troubleshooting

### Build Issues

**Docker not running:**
```bash
# Start Docker Desktop, then retry
make docker-build
```

**Permission denied:**
```bash
chmod +x docker-build.sh build-package.sh test-package-structure.sh
```

### Installation Issues

**Dependencies missing:**
```bash
# On OpenWrt
opkg update
opkg install luci-compat git git-http ca-bundle wget
```

**LuCI doesn't show menu:**
```bash
# Clear cache and restart
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/*
/etc/init.d/uhttpd restart
```

**Watcher not starting:**
```bash
# Check service status
/etc/init.d/git-backup-hook status

# View logs
logread | grep git-backup
```

## Upgrading

To upgrade to a new version:

```bash
# On OpenWrt
opkg remove luci-app-git-backup
opkg install /tmp/luci-app-git-backup_*.ipk
```

Your UCI configuration (`/etc/config/git-backup`) will be preserved.
