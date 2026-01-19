#!/bin/sh
set -e

# Load common functions
. /usr/lib/git-backup/common.sh

# Main restore function
do_restore() {
    local target_commit="$1"

    if [ -z "$target_commit" ]; then
        log_msg err "No commit hash provided for restore"
        echo "ERROR: Commit hash required"
        return 1
    fi

    log_msg info "Starting restore to commit: $target_commit"

    # Load configuration
    load_config

    # Check dependencies
    if ! check_git; then
        log_msg err "Git is not installed"
        echo "ERROR: Git is not installed"
        return 1
    fi

    # Setup git environment
    if ! setup_git_env; then
        log_msg err "Failed to setup git environment"
        echo "ERROR: Failed to setup git environment"
        return 1
    fi

    # Change to root directory
    cd / || return 1

    # Check if git repository exists
    if [ ! -d "/.git" ]; then
        log_msg err "Git repository not initialized"
        echo "ERROR: Git repository not initialized at /"
        return 1
    fi

    # Create safety backup commit before restore
    log_msg info "Creating safety backup before restore"
    git add -A
    if ! git diff --staged --quiet; then
        local safety_msg="Pre-restore safety backup: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        if git commit -m "$safety_msg" 2>&1; then
            git push -u origin "$BRANCH" 2>&1 || log_msg warn "Failed to push safety backup"
            log_msg info "Safety backup created and pushed"
        else
            log_msg warn "No changes to create safety backup"
        fi
    fi

    # Fetch to ensure we have the commit
    log_msg info "Fetching commit from remote"
    if ! git fetch origin "$BRANCH" 2>&1; then
        log_msg err "Failed to fetch from remote"
        echo "ERROR: Failed to fetch from remote repository"
        return 1
    fi

    # Verify commit exists
    if ! git cat-file -e "$target_commit^{commit}" 2>/dev/null; then
        log_msg err "Commit $target_commit not found"
        echo "ERROR: Commit $target_commit not found in repository"
        return 1
    fi

    # Perform restore
    log_msg info "Performing restore to commit $target_commit"
    if ! git reset --hard "$target_commit" 2>&1; then
        log_msg err "Failed to restore to commit $target_commit"
        echo "ERROR: Failed to restore to commit"
        return 1
    fi

    log_msg info "Successfully restored to commit $target_commit"
    echo "SUCCESS: Restored to commit ${target_commit:0:7}"
    echo "IMPORTANT: Some services may need to be restarted for changes to take effect"
    echo "Consider rebooting the device to ensure all changes are applied"

    return 0
}

# Run restore
do_restore "$1"
exit $?
