
#!/bin/bash

# Minecraft project hourly autosave
# Run with: bash autosave.sh

set -u

INTERVAL=3600
BRANCH="main"
LOG_FILE="autosave.log"
MAX_RETRIES=5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Colored logging
log() {
    local color="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${color}[${timestamp}] ${message}${RESET}" | tee -a "$LOG_FILE"
}

echo -e "${CYAN}======================================"
echo " Starting automatic Git backups"
echo " Backups every hour"
echo -e "======================================${RESET}"

# Make sure we're inside a Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "$RED" "ERROR: Not inside a Git repository."
    exit 1
fi

# Make sure origin exists
if ! git remote get-url origin >/dev/null 2>&1; then
    log "$RED" "ERROR: Git remote 'origin' is missing."
    exit 1
fi

# Retry Git push
push_changes() {
    local attempt=1

    while [ "$attempt" -le "$MAX_RETRIES" ]; do
        log "$CYAN" "===============[ Push attempt $attempt/$MAX_RETRIES ]================="

        if git push origin "$BRANCH" --force; then
            log "$GREEN" "SUCCESS: Push successful!"
            return 0
        fi

        log "$RED" "FAILED: Push failed."
        attempt=$((attempt + 1))

        if [ "$attempt" -le "$MAX_RETRIES" ]; then
            log "$YELLOW" "Retrying in 30 seconds..."
            sleep 30
        fi
    done

    log "$RED" "ERROR: Push failed after $MAX_RETRIES attempts."
    return 1
}

# Main autosave loop
while true; do
    log "$CYAN" "Starting backup..."

    # Stage changes
    if ! git add -A; then
        log "$RED" "ERROR: git add failed."
        sleep "$INTERVAL"
        continue
    fi

    # Commit only if there are changes
    if ! git diff --cached --quiet; then
        if git commit -m "Hourly backup $(date '+%Y-%m-%d %H:%M:%S')"; then
            log "$GREEN" "SUCCESS: Commit created."
        else
            log "$RED" "ERROR: Commit failed."
            sleep "$INTERVAL"
            continue
        fi
    else
        log "$YELLOW" "No changes to commit."
    fi

    # Push existing and new commits
    if ! push_changes; then
        log "$RED" "Backup remains local. Will retry next hour."
    fi

    log "$GREEN" "Next backup in one hour."
    sleep "$INTERVAL"
done
