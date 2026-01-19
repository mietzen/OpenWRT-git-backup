#!/bin/sh
# Verify git environment is set correctly

echo "=== Verifying Git Environment Setup ==="
echo ""

# Source the common functions
. /usr/lib/git-backup/common.sh

echo "1. Loading configuration..."
load_config

echo "   GIT_USER_NAME from UCI: $GIT_USER_NAME"
echo "   GIT_USER_EMAIL from UCI: $GIT_USER_EMAIL"
echo ""

echo "2. Setting up git environment..."
setup_git_env

echo ""
echo "3. Checking exported environment variables..."
echo "   GIT_AUTHOR_NAME: $GIT_AUTHOR_NAME"
echo "   GIT_AUTHOR_EMAIL: $GIT_AUTHOR_EMAIL"
echo "   GIT_COMMITTER_NAME: $GIT_COMMITTER_NAME"
echo "   GIT_COMMITTER_EMAIL: $GIT_COMMITTER_EMAIL"
echo ""

echo "4. Checking git config..."
git config --global user.name || echo "   (not set in global config)"
git config --global user.email || echo "   (not set in global config)"
echo ""

echo "5. Testing git commit with current environment..."
cd /tmp
rm -rf test-git-env
mkdir test-git-env
cd test-git-env
git init
echo "test" > test.txt
git add test.txt

echo "   Attempting commit..."
if git commit -m "Test commit" 2>&1; then
    echo "   ✓ Success! Git can create commits with current environment"
else
    echo "   ✗ Failed! Git identity not working"
fi

cd /tmp
rm -rf test-git-env

echo ""
echo "=== Verification Complete ==="
