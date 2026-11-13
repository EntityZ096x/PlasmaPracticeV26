
#!/bin/bash

# Minecraft project hourly autosave
# Run with: bash autosave.sh

set -u

INTERVAL=3600
BRANCH="main"
LOG_FILE="autosave.log"
MAX_RETRIES=5

echo "======================================"
echo " Starting automatic Git backups"
echo " Backups every hour"
echo "======================================"

# Make sure we're inside a Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: Not inside a Git repository."
    exit 1
fi

# Make sure origin exists
if ! git remote get-url origin >/dev/null 2>&1; then
    echo "ERROR: Git remote 'origin' is missing."
    exit 1
fi

# Save logs
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Retry Git push
push_changes() {
    local attempt=1

    while [ "$attempt" -le "$MAX_RETRIES" ]; do
        log "===============[ Push attempt $attempt/$MAX_RETRIES ]================="

        if git push origin "$BRANCH" --force; then
            log "Push successful!"
            return 0
        fi

        log "Push failed. Retrying in 30 seconds..."
        sleep 30
        attempt=$((attempt + 1))
    done

    log "ERROR: Push failed after $MAX_RETRIES attempts."
    return 1
}

# Main autosave loop
while true; do
    log "Starting backup..."

    # Stage changes
    if ! git add -A; then
        log "ERROR: git add failed."
        sleep "$INTERVAL"
        continue
    fi

    # Commit only if there are changes
    if ! git diff --cached --quiet; then
        if git commit -m "Hourly backup $(date '+%Y-%m-%d %H:%M:%S')"; then
            log "Commit created."
        else
            log "ERROR: Commit failed."
            sleep "$INTERVAL"
            continue
        fi
    else
        log "No changes to commit."
    fi

    # Push existing and new commits
    if ! push_changes; then
        log "Backup remains local. Will retry next hour."
    fi

    log "Next backup in one hour."
    sleep "$INTERVAL"
done
