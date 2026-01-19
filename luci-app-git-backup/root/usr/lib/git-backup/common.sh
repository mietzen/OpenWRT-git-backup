#!/bin/sh
# Common functions for git-backup

# Load UCI config
load_config() {
    ENABLED=$(uci -q get git-backup.settings.enabled)
    AUTH_TYPE=$(uci -q get git-backup.settings.auth_type)
    REPO_URL=$(uci -q get git-backup.settings.repo_url)
    BRANCH=$(uci -q get git-backup.settings.branch)
    SSH_KEY_PATH=$(uci -q get git-backup.settings.ssh_key_path)
    HTTPS_USERNAME=$(uci -q get git-backup.settings.https_username)
    HTTPS_TOKEN=$(uci -q get git-backup.settings.https_token)
    BACKUP_DIRS=$(uci -q get git-backup.settings.backup_dirs)
    MAX_COMMITS=$(uci -q get git-backup.settings.max_commits)
    GIT_USER_NAME=$(uci -q get git-backup.settings.git_user_name)
    GIT_USER_EMAIL=$(uci -q get git-backup.settings.git_user_email)

    # Default to hostname if branch is 'auto'
    if [ "$BRANCH" = "auto" ]; then
        BRANCH=$(cat /proc/sys/kernel/hostname)
    fi
}

# Update last backup status in UCI
update_status() {
    local status="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    uci set git-backup.settings.last_backup_time="$timestamp"
    uci set git-backup.settings.last_backup_status="$status"
    uci set git-backup.settings.last_backup_message="$message"
    uci commit git-backup
}

# Log message
log_msg() {
    local level="$1"
    local message="$2"
    logger -t git-backup -p "user.$level" "$message"
    echo "[$(date)] [$level] $message" >&2
}

# Check if git is installed
check_git() {
    if ! command -v git >/dev/null 2>&1; then
        log_msg err "git is not installed"
        return 1
    fi
    return 0
}

# Setup git environment
setup_git_env() {
    # Configure git globally
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"

    # Setup authentication
    if [ "$AUTH_TYPE" = "ssh" ]; then
        if [ ! -f "$SSH_KEY_PATH" ]; then
            log_msg err "SSH key not found at $SSH_KEY_PATH"
            return 1
        fi
        export GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null"
    elif [ "$AUTH_TYPE" = "https" ]; then
        # Setup credential helper
        local cred_file="/etc/git-backup/.git-credentials"
        local repo_host=$(echo "$REPO_URL" | sed -E 's~^https?://~~' | cut -d/ -f1)

        mkdir -p /etc/git-backup
        echo "https://${HTTPS_USERNAME}:${HTTPS_TOKEN}@${repo_host}" > "$cred_file"
        chmod 600 "$cred_file"

        git config --global credential.helper "store --file=$cred_file"
    fi
}

# Initialize git repository at /
init_git_repo() {
    cd / || return 1

    if [ ! -d "/.git" ]; then
        log_msg info "Initializing git repository at /"
        git init
        git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"

        # Create .gitignore
        create_gitignore
    else
        # Update remote URL in case it changed
        git remote set-url origin "$REPO_URL"
    fi

    # Fetch and checkout branch
    git fetch origin "$BRANCH" --depth="$MAX_COMMITS" 2>/dev/null || true
    git checkout -B "$BRANCH" 2>/dev/null || true
    git branch --set-upstream-to=origin/"$BRANCH" "$BRANCH" 2>/dev/null || true

    return 0
}

# Create .gitignore file
create_gitignore() {
    cat > /.gitignore << 'EOF'
# Include only specific directories
/*
!/.gitignore

# Include configured backup directories
EOF

    # Add backup directories to gitignore (as negations)
    for dir in $BACKUP_DIRS; do
        echo "!${dir}" >> /.gitignore
        echo "!${dir}/**" >> /.gitignore
    done
}

# Check if there are changes to commit
has_changes() {
    git add -A
    ! git diff --staged --quiet
}

# Get current commit hash
get_current_commit() {
    git rev-parse HEAD 2>/dev/null || echo "none"
}

# Get remote commit history (JSON format for LuCI)
get_remote_history() {
    local max_count="${1:-50}"

    git fetch origin "$BRANCH" --depth="$max_count" 2>/dev/null || return 1

    # Output format: hash|timestamp|message
    git log "origin/$BRANCH" --pretty=format:"%H|%ai|%s" --max-count="$max_count" 2>/dev/null
}
