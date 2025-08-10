#!/bin/bash

# Simplified but robust merge script
set -euo pipefail

# Configuration
REPO_URL="https://github.com/ArnaudDavyMM/Time_Series_Analysis.git"
CLONE_DIR="Time_Series_Analysis_repo"
BACKUP_DIR="Time_Series_Analysis_backup_$(date +%Y%m%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${2:-$NC}$1${NC}"; }

# Error cleanup
cleanup() {
    if [ $? -ne 0 ] && [ -d "$CLONE_DIR" ]; then
        log "❌ Cleaning up after error..." $RED
        rm -rf "$CLONE_DIR"
    fi
}
trap cleanup EXIT

# Quick validations
validate_requirements() {
    command -v git >/dev/null || { log "❌ Git not found" $RED; exit 1; }
    ping -c 1 github.com >/dev/null 2>&1 || { log "❌ Cannot reach GitHub" $RED; exit 1; }
}

get_local_directory() {
    while true; do
        read -p "📁 Enter path to your local project folder: " LOCAL_DIR
        LOCAL_DIR="${LOCAL_DIR/#\~/$HOME}"
        
        if [ ! -d "$LOCAL_DIR" ]; then
            log "❌ Directory doesn't exist: $LOCAL_DIR" $RED
            continue
        fi
        
        if [ -z "$(ls -A "$LOCAL_DIR" 2>/dev/null)" ]; then
            log "⚠️  Directory is empty: $LOCAL_DIR" $YELLOW
            read -p "Continue anyway? (y/n): " confirm
            [[ "$confirm" != "y" ]] && continue
        fi
        
        break
    done
    log "✅ Using: $LOCAL_DIR" $GREEN
}

# Main script
log "🚀 Starting merge script..." $GREEN

# Pre-flight checks
validate_requirements

# Check for existing clone directory
if [ -d "$CLONE_DIR" ]; then
    log "⚠️  Clone directory '$CLONE_DIR' already exists!" $YELLOW
    read -p "Remove it and continue? (y/n): " remove_confirm
    if [[ "$remove_confirm" == "y" ]]; then
        rm -rf "$CLONE_DIR"
        log "🗑️  Removed existing directory" $YELLOW
    else
        log "❌ Aborted to prevent overwrites" $RED
        exit 1
    fi
fi

get_local_directory

# Clone and backup
log "🔄 Cloning repository..." $BLUE
git clone "$REPO_URL" "$CLONE_DIR"

log "🛡️  Creating backup..." $BLUE
cp -r "$CLONE_DIR" "$BACKUP_DIR"
log "✅ Backup: $BACKUP_DIR" $GREEN

cd "$CLONE_DIR"
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Check for large files
log "🔍 Checking for large files..." $BLUE
large_files=$(find "$LOCAL_DIR" -type f -size +50M 2>/dev/null || true)
if [ -n "$large_files" ]; then
    log "⚠️  Large files found (>50MB):" $YELLOW
    echo "$large_files" | head -3
    read -p "Continue? (y/n): " confirm
    [[ "$confirm" != "y" ]] && exit 1
fi

# Copy files
log "📁 Copying files..." $BLUE
rsync -a --exclude='.git' --exclude='.DS_Store' --exclude='__pycache__' "$LOCAL_DIR/" ./

# Handle .gitignore conflicts
if [ -f "$LOCAL_DIR/.gitignore" ] && [ -f ".gitignore" ]; then
    log "⚠️  Both have .gitignore files" $YELLOW
    read -p "Merge them? (y/n): " merge_ignore
    if [[ "$merge_ignore" == "y" ]]; then
        cat .gitignore "$LOCAL_DIR/.gitignore" | sort -u > .gitignore.tmp
        mv .gitignore.tmp .gitignore
        log "✅ .gitignore files merged" $GREEN
    fi
fi

# Show changes
log "🔍 Changes preview..." $BLUE
git status --short | head -10
echo ""

if git diff --quiet && git diff --cached --quiet; then
    log "ℹ️  No changes to commit" $YELLOW
    cd .. && rm -rf "$CLONE_DIR"
    exit 0
fi

# Change summary
added=$(git status --porcelain | grep -c "^??" || echo "0")
modified=$(git status --porcelain | grep -c "^.M" || echo "0")
log "📊 New: $added, Modified: $modified" $BLUE

# Commit confirmation
read -p "💬 Commit message (Enter for default): " custom_message
COMMIT_MESSAGE="${custom_message:-"Merged local project files - $(date +%Y-%m-%d)"}"

read -p "🚀 Commit and push? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    log "❌ Aborted. Backup safe at: $BACKUP_DIR" $YELLOW
    exit 1
fi

# Commit and push
log "✅ Committing..." $GREEN
git add .
git commit -m "$COMMIT_MESSAGE"

log "📤 Pushing to $DEFAULT_BRANCH..." $GREEN
git push origin "$DEFAULT_BRANCH"

# Success
log "🎉 Merge complete!" $GREEN
echo "✅ Repository: $REPO_URL"
echo "✅ Backup: $BACKUP_DIR"
echo "✅ Commit: $(git rev-parse --short HEAD)"

# Automatic cleanup after successful push
log "🧹 Cleaning up temporary repository..." $BLUE
cd ..
rm -rf "$CLONE_DIR"
log "✅ Removed: $CLONE_DIR" $GREEN

log "✨ Done!" $GREEN
