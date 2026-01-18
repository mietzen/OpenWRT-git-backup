# OpenWRT Git Backup

Automated backup service for OpenWRT that commits configuration changes to a GitHub repository.

## Prerequisites

```bash
opkg update
opkg install git wget
```

## Installation

1. Download the backup script and service file:

```bash
mkdir -p /usr/local/bin/
wget https://raw.githubusercontent.com/mietzen/OpenWRT-git-backup/main/git_backup -O /usr/local/bin/git_backup
wget https://raw.githubusercontent.com/mietzen/OpenWRT-git-backup/main/S99git_backup -O /etc/init.d/S99git_backup
chmod +x /usr/local/bin/git_backup
chmod +x /etc/init.d/git_backup
```

2. Start the service (this will generate an SSH key on first run):

```bash
/etc/init.d/git_backup start
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
/etc/init.d/git_backup restart
```

6. Enable the service to start on boot:

```bash
/etc/init.d/git_backup enable
```

## Configuration

Edit `/usr/local/bin/git_backup` to customize:
- `REPO_URL`: Your GitHub repository URL
- `INTERVAL`: Backup interval in seconds (default: 300)

## Monitoring

View logs:
```bash
tail -f /var/log/git_backup.log
```

Check service status:
```bash
/etc/init.d/git_backup status
```
