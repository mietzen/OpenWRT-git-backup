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

    # Update .gitignore in case backup_dirs changed
    create_gitignore

    # Check for changes
    if ! has_changes; then
        log_msg info "No changes to backup"
        update_status "success" "No changes detected"
        return 0
    fi

    # Create commit
    local commit_msg="Backup: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    if ! git commit -m "$commit_msg" 2>&1; then
        update_status "failed" "Failed to create commit"
        log_msg err "Failed to create commit"
        return 1
    fi

    log_msg info "Created commit: $commit_msg"

    # Push to remote
    if ! git push -u origin "$BRANCH" 2>&1; then
        update_status "failed" "Failed to push to remote"
        log_msg err "Failed to push to remote repository"
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
