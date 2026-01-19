#!/bin/sh
# Common functions for git-backup

# Load UCI config
load_config() {
    ENABLED=$(uci -q get git-backup.settings.enabled || echo "0")
    AUTH_TYPE=$(uci -q get git-backup.settings.auth_type || echo "ssh")
    REPO_URL=$(uci -q get git-backup.settings.repo_url || echo "")
    BRANCH=$(uci -q get git-backup.settings.branch || echo "auto")
    SSH_KEY_PATH=$(uci -q get git-backup.settings.ssh_key_path || echo "/etc/git-backup/keys/id_ed25519")
    HTTPS_USERNAME=$(uci -q get git-backup.settings.https_username || echo "")
    HTTPS_TOKEN=$(uci -q get git-backup.settings.https_token || echo "")
    BACKUP_DIRS=$(uci -q get git-backup.settings.backup_dirs || echo "/etc")
    MAX_COMMITS=$(uci -q get git-backup.settings.max_commits || echo "5")
    GIT_USER_NAME=$(uci -q get git-backup.settings.git_user_name || echo "OpenWRT Backup")
    GIT_USER_EMAIL=$(uci -q get git-backup.settings.git_user_email || echo "backup@openwrt")

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
    # Disable pager to prevent interactive prompts
    export GIT_PAGER=cat

    # Export git identity as environment variables as fallback
    # Repository-level config is set in init_git_repo(), but env vars provide defense-in-depth
    export GIT_AUTHOR_NAME="$GIT_USER_NAME"
    export GIT_AUTHOR_EMAIL="$GIT_USER_EMAIL"
    export GIT_COMMITTER_NAME="$GIT_USER_NAME"
    export GIT_COMMITTER_EMAIL="$GIT_USER_EMAIL"

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

    # Configure git identity at repository level (always available, no HOME required)
    git config user.name "$GIT_USER_NAME"
    git config user.email "$GIT_USER_EMAIL"

    # Fetch and checkout branch
    git fetch origin "$BRANCH" --depth="$MAX_COMMITS" 2>/dev/null || true

    # Check if remote branch exists and sync with it
    if git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
        log_msg info "Remote branch '$BRANCH' exists, syncing with it"
        # Remote branch exists, create local branch from remote
        git checkout -B "$BRANCH" "origin/$BRANCH"
        git branch --set-upstream-to=origin/"$BRANCH" "$BRANCH" 2>/dev/null || true
        # Reset index to HEAD to ensure clean state (preserves working tree changes)
        git reset --mixed HEAD >/dev/null 2>&1 || true
    else
        log_msg info "Remote branch '$BRANCH' does not exist, creating new branch"
        # Remote branch doesn't exist, create new empty branch
        git checkout -B "$BRANCH"
    fi

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

    # Process each backup path
    for path in $BACKUP_DIRS; do
        # Remove leading slash for processing
        path_clean="${path#/}"

        # Split path into components
        current=""
        prev=""
        IFS='/'
        for component in $path_clean; do
            prev="$current"
            if [ -z "$current" ]; then
                current="$component"
            else
                current="$current/$component"
            fi

            # Un-exclude this directory level
            echo "!/${current}" >> /.gitignore

            # For parent directories (not the final component), exclude their contents
            # This creates the whitelist pattern for nested paths
            if [ "$current" != "$path_clean" ]; then
                echo "/${current}/*" >> /.gitignore
            fi
        done
        unset IFS

        # If the final path is a directory, include all its contents
        if [ -d "$path" ]; then
            echo "!${path}/**" >> /.gitignore
        fi
    done

    # Exclude runtime metadata files that change on every backup
    cat >> /.gitignore << 'EOF'

# Exclude git-backup runtime metadata to prevent uncommitted changes
/etc/config/git-backup
EOF
}

# Update .gitignore only if needed (doesn't exist or backup_dirs changed)
update_gitignore_if_needed() {
    local marker_file="/.git/.backup_dirs_state"
    local saved_dirs

    # Read saved backup dirs
    saved_dirs=$(cat "$marker_file" 2>/dev/null || echo "")

    # Check if gitignore needs updating
    if [ ! -f /.gitignore ] || [ "$BACKUP_DIRS" != "$saved_dirs" ]; then
        log_msg info "Updating .gitignore (backup directories changed or missing)"
        create_gitignore
        echo "$BACKUP_DIRS" > "$marker_file"
    fi
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
