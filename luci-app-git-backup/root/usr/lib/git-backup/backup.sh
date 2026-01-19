#!/bin/sh
set -e

# Load common functions
. /usr/lib/git-backup/common.sh

# Main backup function
do_backup() {
    log_msg info "Starting backup process"

    # Load configuration
    load_config

    # Check if enabled
    if [ "$ENABLED" != "1" ]; then
        log_msg warn "Git backup is disabled"
        return 1
    fi

    # Validate configuration
    if [ -z "$REPO_URL" ]; then
        update_status "failed" "Repository URL not configured"
        log_msg err "Repository URL not configured"
        return 1
    fi

    # Check dependencies
    if ! check_git; then
        update_status "failed" "Git is not installed"
        return 1
    fi

    # Setup git environment
    if ! setup_git_env; then
        update_status "failed" "Failed to setup git environment"
        return 1
    fi

    # Initialize repository
    if ! init_git_repo; then
        update_status "failed" "Failed to initialize git repository"
        log_msg err "Failed to initialize git repository"
        return 1
    fi

    # Change to root directory
    cd / || return 1

    # Update .gitignore only if backup_dirs changed or file missing
    update_gitignore_if_needed

    # Remove git-backup config from index if previously tracked (ignore errors)
    git rm --cached etc/config/git-backup >/dev/null 2>&1 || true

    # Log current git status for debugging
    local status_output=$(git status --short 2>&1)
    if [ -n "$status_output" ]; then
        log_msg info "Git status before commit: $status_output"
    fi

    # Check for changes
    if ! has_changes; then
        log_msg info "No changes to backup"
        update_status "success" "No changes detected"
        return 0
    fi

    # Log what we're about to commit
    log_msg info "Changes detected, creating commit"

    # Create commit with error capture
    local commit_msg="Backup: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    local commit_output
    if ! commit_output=$(git commit -m "$commit_msg" 2>&1); then
        log_msg err "Git commit failed: $commit_output"
        update_status "failed" "Failed to create commit: $commit_output"
        return 1
    fi

    log_msg info "Created commit: $commit_msg"

    # Push to remote with error capture
    local push_output
    if ! push_output=$(git push -u origin "$BRANCH" 2>&1); then
        log_msg err "Git push failed: $push_output"
        update_status "failed" "Failed to push to remote: $push_output"
        return 1
    fi

    log_msg info "Successfully pushed to remote"

    # Limit local history to save space
    if [ -n "$MAX_COMMITS" ] && [ "$MAX_COMMITS" -gt 0 ]; then
        log_msg info "Limiting local history to $MAX_COMMITS commits"

        # Fetch with depth limit
        git fetch origin "$BRANCH" --depth="$MAX_COMMITS" 2>&1 || true

        # Reset to fetched state
        git reset --hard "origin/$BRANCH" 2>&1 || true

        # Garbage collection
        git gc --prune=all 2>&1 || true

        log_msg info "Local history maintenance completed"
    fi

    # Update status
    local current_commit=$(get_current_commit)
    update_status "success" "Backup completed successfully (commit: ${current_commit:0:7})"
    log_msg info "Backup completed successfully"

    return 0
}

# Run backup
do_backup
exit $?
