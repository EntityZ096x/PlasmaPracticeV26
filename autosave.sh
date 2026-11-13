
#!/bin/bash

# ==========================================
#       MINECRAFT AUTO BACKUP MANAGER
# ==========================================

set -u

INTERVAL=3600
BRANCH="main"
LOG_FILE="autosave.log"
MAX_RETRIES=5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[0;37m'
RESET='\033[0m'

# Logging
log() {
    local color="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${color}[${timestamp}] ${message}${RESET}" | tee -a "$LOG_FILE"
}

# Countdown formatter
format_time() {
    local seconds=$1
    printf "%02dh %02dm %02ds" \
        $((seconds / 3600)) \
        $(((seconds % 3600) / 60)) \
        $((seconds % 60))
}

# Show repository information
show_info() {
    echo
    echo -e "${WHITE}========== BACKUP INFORMATION ==========${RESET}"
    echo -e "${WHITE}Repository: $(basename "$(git rev-parse --show-toplevel)")${RESET}"
    echo -e "${WHITE}Branch:     $BRANCH${RESET}"
    echo -e "${WHITE}Remote:     $(git remote get-url origin)${RESET}"
    echo -e "${WHITE}Interval:   $(format_time "$INTERVAL")${RESET}"
    echo -e "${WHITE}Last commit: $(git rev-parse --short HEAD)${RESET}"
    echo -e "${WHITE}=========================================${RESET}"
    echo
}

# Show changed file count
show_changes() {
    local changes
    changes=$(git status --short | wc -l)
    log "$WHITE" "Changed files detected: $changes"
}

# Retry Git push
push_changes() {
    local attempt=1

    while [ "$attempt" -le "$MAX_RETRIES" ]; do
        log "$WHITE" "========== PUSH ATTEMPT $attempt/$MAX_RETRIES =========="

        if git push origin "$BRANCH" --force; then
            log "$GREEN" "SUCCESS: Push completed!"
            return 0
        fi

        log "$RED" "FAILED: Push failed."
        attempt=$((attempt + 1))

        if [ "$attempt" -le "$MAX_RETRIES" ]; then
            log "$YELLOW" "Retrying in 30 seconds..."
            sleep 30
        fi
    done

    log "$RED" "ERROR: All push attempts failed."
    return 1
}

# Initial checks
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Not inside a Git repository.${RESET}"
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Git remote origin is missing.${RESET}"
    exit 1
fi

clear

echo -e "${GREEN}"
echo "=============================================="
echo "          MINECRAFT AUTO BACKUP"
echo "=============================================="
echo -e "${RESET}"

show_info

log "$GREEN" "Backup manager started successfully!"

# Main loop
while true; do

    START_TIME=$(date +%s)

    echo
    log "$WHITE" "========== STARTING BACKUP =========="

    show_changes

    # Stage changes
    if ! git add -A; then
        log "$RED" "ERROR: git add failed."
        sleep "$INTERVAL"
        continue
    fi

    # Commit changes
    if ! git diff --cached --quiet; then

        if git commit -m "Hourly backup $(date '+%Y-%m-%d %H:%M:%S')"; then
            log "$GREEN" "SUCCESS: Commit created!"
        else
            log "$RED" "ERROR: Commit failed."
            sleep "$INTERVAL"
            continue
        fi

    else
        log "$YELLOW" "No changes detected. Skipping commit."
    fi

    # Push
    if ! push_changes; then
        log "$RED" "Backup remains local. Push needs attention."
    fi

    # Backup duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    log "$WHITE" "Backup duration: $(format_time "$DURATION")"

    # Latest commit
    log "$WHITE" "Latest commit: $(git rev-parse --short HEAD)"

    # Next backup timestamp
    NEXT_BACKUP=$(( $(date +%s) + INTERVAL ))

    log "$GREEN" "NEXT BACKUP: $(date -d "@$NEXT_BACKUP" '+%Y-%m-%d %H:%M:%S')"

    echo
    log "$YELLOW" "Waiting for next backup..."

    # Countdown
    REMAINING=$INTERVAL

    while [ "$REMAINING" -gt 0 ]; do
        printf "\r${WHITE}Next backup in: $(format_time "$REMAINING")${RESET}   "
        sleep 1
        REMAINING=$((REMAINING - 1))
    done

    echo
done
