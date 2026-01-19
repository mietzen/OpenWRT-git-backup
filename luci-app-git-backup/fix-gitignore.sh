#!/bin/sh
# Fix script to clean up git-backup config from repository

echo "Fixing git repository to exclude git-backup runtime metadata..."

cd /

# Check if git-backup config is currently tracked
if git ls-files --error-unmatch etc/config/git-backup >/dev/null 2>&1; then
    echo "Removing etc/config/git-backup from git index..."
    git rm --cached etc/config/git-backup

    # Commit the removal
    echo "Creating commit to remove runtime metadata file..."
    git commit -m "Remove git-backup runtime metadata from tracking

The git-backup config file contains runtime status fields that change
on every backup, causing unnecessary commits and conflicts. This file
is now excluded via .gitignore."

    # Push the change
    echo "Pushing to remote..."
    git push
else
    echo "etc/config/git-backup is not currently tracked, nothing to do."
fi

echo ""
echo "Verifying .gitignore..."
if grep -q "/etc/config/git-backup" /.gitignore; then
    echo "✓ git-backup config is excluded in .gitignore"
else
    echo "✗ WARNING: git-backup config not found in .gitignore"
    echo "  Run a backup to regenerate .gitignore"
fi

echo ""
echo "Checking for uncommitted changes..."
git status --short

echo ""
echo "Done! The git-backup config will no longer be tracked."
echo "Runtime status updates won't create uncommitted changes anymore."
