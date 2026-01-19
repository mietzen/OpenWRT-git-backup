#!/bin/sh
# Debug script for backup issues

echo "=========================================="
echo "Git Backup Debug Information"
echo "=========================================="
echo ""

echo "1. Checking UCI Configuration..."
echo ""
uci show git-backup
echo ""

echo "2. Checking if backup script is executable..."
echo ""
ls -la /usr/bin/git-backup
echo ""

echo "3. Testing manual backup with verbose output..."
echo ""
/usr/bin/git-backup backup
echo ""

echo "4. Checking git repository status..."
echo ""
if [ -d /.git ]; then
    echo "[OK] Git repository exists at /"
    cd /
    echo ""
    echo "Git status:"
    git status
    echo ""
    echo "Git remote:"
    git remote -v
    echo ""
    echo "Git branch:"
    git branch -a
else
    echo "[FAIL] No git repository found at /"
fi
echo ""

echo "5. Checking logs..."
echo ""
logread | grep git-backup | tail -20
echo ""

echo "6. Checking if git can connect to remote..."
echo ""
REPO_URL=$(uci -q get git-backup.settings.repo_url)
AUTH_TYPE=$(uci -q get git-backup.settings.auth_type)

if [ -n "$REPO_URL" ]; then
    echo "Repository URL: $REPO_URL"
    echo "Auth Type: $AUTH_TYPE"
    echo ""

    if [ "$AUTH_TYPE" = "ssh" ]; then
        SSH_KEY=$(uci -q get git-backup.settings.ssh_key_path)
        echo "Testing SSH key: $SSH_KEY"
        if [ -f "$SSH_KEY" ]; then
            ls -la "$SSH_KEY"
            echo ""
            # Extract host from URL (e.g., github.com from git@github.com:user/repo.git)
            HOST=$(echo "$REPO_URL" | sed -E 's/.*@([^:]+):.*/\1/')
            echo "Testing SSH connection to $HOST..."
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -T git@"$HOST" 2>&1 | head -5
        else
            echo "[FAIL] SSH key not found at $SSH_KEY"
        fi
    elif [ "$AUTH_TYPE" = "https" ]; then
        echo "Testing HTTPS connection..."
        # Check if git-http is installed
        if opkg list-installed | grep -q "^git-http"; then
            echo "[OK] git-http is installed"
        else
            echo "[FAIL] git-http is NOT installed - HTTPS will not work!"
            echo "Install with: opkg install git-http ca-bundle"
        fi
    fi
else
    echo "[FAIL] No repository URL configured"
fi

echo ""
echo "=========================================="
echo "Debug Complete"
echo "=========================================="
