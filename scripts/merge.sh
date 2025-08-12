#!/bin/bash

# Minimal repository replacement script (replace.sh)
# Publishes only documentation and config while keeping development private
# Version: 1.0.1
set -euo pipefail

# Script metadata
SCRIPT_VERSION="1.0.1"
SCRIPT_NAME="merge.sh"
MIN_BASH_VERSION=4

# Configuration
REPO_URL="https://github.com/ArnaudDavyMM/Time_Series_Analysis.git"
WORK_DIR="Time_Series_Analysis_update"
BACKUP_DIR="Time_Series_Analysis_backup_$(date +%Y-%m-%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${2:-$NC}$1${NC}"; }

# Error cleanup
cleanup() {
    if [ $? -ne 0 ] && [ -d "$WORK_DIR" ]; then
        log "❌ Cleaning up after error..." $RED
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

# Validations
validate_requirements() {
    # Check Bash version
    if [ "${BASH_VERSION%%.*}" -lt $MIN_BASH_VERSION ]; then
        log "❌ Bash $MIN_BASH_VERSION+ required (you have $BASH_VERSION)" $RED
        exit 1
    fi
    
    # Check required commands
    for cmd in git rsync; do
        if ! command -v "$cmd" >/dev/null; then
            log "❌ Required command not found: $cmd" $RED
            exit 1
        fi
    done
    
    # Network check
    if ! ping -c 1 github.com >/dev/null 2>&1; then
        log "❌ Cannot reach GitHub" $RED
        exit 1
    fi
    
    # Disk space check (need at least 100MB)
    local available_mb=$(df . | awk 'NR==2 {print int($4/1024)}')
    if [ "$available_mb" -lt 100 ]; then
        log "⚠️  Low disk space: ${available_mb}MB available" $YELLOW
        read -p "Continue anyway? (y/n): " continue_low_space
        [[ "$continue_low_space" != "y" ]] && exit 1
    fi
}

setup_git_auth() {
    # Check if GitHub token is available
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        log "✅ Using GITHUB_TOKEN from environment" $GREEN
        git config --global credential.helper store
        echo "https://${GITHUB_TOKEN}@github.com" > ~/.git-credentials
    elif [ -f ~/.git-credentials ] || git config --get credential.helper >/dev/null; then
        log "✅ Using existing Git credentials" $GREEN
    else
        log "⚠️  No GitHub token found in environment" $YELLOW
        read -p "Enter your GitHub personal access token: " -s user_token
        echo ""
        if [ -n "$user_token" ]; then
            export GITHUB_TOKEN="$user_token"
            git config --global credential.helper store
            echo "https://${GITHUB_TOKEN}@github.com" > ~/.git-credentials
            log "✅ GitHub token configured" $GREEN
        else
            log "❌ No token provided. You may need to authenticate during push" $YELLOW
        fi
    fi
}

detect_default_branch() {
    local repo_url="$1"
    log "🔍 Detecting default branch for $repo_url..." $BLUE
    
    # Method 1: Try GitHub's symbolic ref (most reliable)
    local symref_output=$(git ls-remote --symref "$repo_url" HEAD 2>/dev/null || echo "")
    if [ -n "$symref_output" ]; then
        # Look for line like "ref: refs/heads/main	HEAD"
        local default_branch=$(echo "$symref_output" | grep "^ref:" | head -1 | sed 's/^ref: refs\/heads\///' | sed 's/[[:space:]]*HEAD$//' | tr -d '\t\r\n ')
        if [ -n "$default_branch" ] && [ "$default_branch" != "HEAD" ]; then
            log "   ✅ Found via symbolic ref: $default_branch" $GREEN
            echo "$default_branch"
            return
        fi
    fi
    
    # Method 2: Get the HEAD commit hash and find matching branch
    local head_hash=$(git ls-remote "$repo_url" HEAD 2>/dev/null | cut -f1)
    if [ -n "$head_hash" ]; then
        local matching_branch=$(git ls-remote --heads "$repo_url" 2>/dev/null | grep "^$head_hash" | head -1 | sed 's/.*refs\/heads\///' | tr -d '\t\r\n ')
        if [ -n "$matching_branch" ]; then
            log "   ✅ Found via HEAD hash: $matching_branch" $GREEN
            echo "$matching_branch"
            return
        fi
    fi
    
    # Method 3: Get available branches and use priority order
    log "   🔍 Falling back to branch enumeration..." $YELLOW
    local branches=($(git ls-remote --heads "$repo_url" 2>/dev/null | sed 's/.*refs\/heads\///' | tr -d '\t\r\n ' | sort))
    
    if [ ${#branches[@]} -eq 0 ]; then
        log "   ⚠️  No branches found, defaulting to 'main'" $YELLOW
        echo "main"
        return
    fi
    
    # If only one branch, use it
    if [ ${#branches[@]} -eq 1 ]; then
        log "   ✅ Single branch found: ${branches[0]}" $GREEN
        echo "${branches[0]}"
        return
    fi
    
    # Multiple branches - check priority order
    log "   📋 Available branches: ${branches[*]}" $BLUE
    for preferred in main master develop mmad; do
        for branch in "${branches[@]}"; do
            if [ "$branch" = "$preferred" ]; then
                log "   ✅ Using preferred branch: $branch" $GREEN
                echo "$branch"
                return
            fi
        done
    done
    
    # Fallback to first branch
    log "   ⚠️  Using first available branch: ${branches[0]}" $YELLOW
    echo "${branches[0]}"
}

get_local_directory() {
    while true; do
        read -p "📁 Enter path to your Time_Series_Analysis project: " LOCAL_DIR
        LOCAL_DIR="${LOCAL_DIR/#\~/$HOME}"
        LOCAL_DIR="$(realpath "$LOCAL_DIR" 2>/dev/null || echo "$LOCAL_DIR")"
        
        if [ ! -d "$LOCAL_DIR" ]; then
            log "❌ Directory doesn't exist: $LOCAL_DIR" $RED
            continue
        fi
        
        # Verify it has the expected structure
        if [ ! -d "$LOCAL_DIR/notebooks" ]; then
            log "❌ Missing notebooks/ directory" $RED
            continue
        fi
        
        if [ ! -f "$LOCAL_DIR/README.md" ]; then
            log "⚠️  No README.md found" $YELLOW
            read -p "Continue without main README? (y/n): " no_readme
            [[ "$no_readme" != "y" ]] && continue
        fi
        
        # Check for sensitive files that shouldn't be public
        sensitive_files=()
        for pattern in "*.key" "*.pem" "*secret*" "*password*" ".env" "config.json"; do
            if find "$LOCAL_DIR" -maxdepth 2 -name "$pattern" 2>/dev/null | grep -q .; then
                sensitive_files+=($(find "$LOCAL_DIR" -maxdepth 2 -name "$pattern" 2>/dev/null | head -3))
            fi
        done
        
        if [ ${#sensitive_files[@]} -gt 0 ]; then
            log "🔒 Sensitive files detected:" $YELLOW
            printf '%s\n' "${sensitive_files[@]}"
            log "These will be excluded from the public repository" $GREEN
        fi
        
        break
    done
    log "✅ Using project directory: $LOCAL_DIR" $GREEN
}

get_version_tag() {
    local today=$(date +%Y-%m-%d)
    local patch=1
    
    # Check if we're in git repo to look for existing tags
    if [ -d ".git" ]; then
        # Find highest patch number for today
        local existing_patches=$(git tag -l "v${today}.*" 2>/dev/null | sed "s/v${today}\.//" | sort -n | tail -1)
        if [ -n "$existing_patches" ]; then
            patch=$((existing_patches + 1))
        fi
    fi
    
    echo "v${today}.${patch}"
}

copy_public_files() {
    local source_dir="$1"
    local files_copied=0
    
    log "📋 Copying public documentation and configuration..." $BLUE
    
    # Copy notebooks structure (READMEs only)
    if [ -d "$source_dir/notebooks" ]; then
        cp -r "$source_dir/notebooks" .
        # Remove any actual notebooks, keep only READMEs and docs
        find ./notebooks -name "*.ipynb" -delete 2>/dev/null || true
        files_copied=$((files_copied + $(find ./notebooks -type f | wc -l)))
        log "   ✅ notebooks/ (READMEs only)" $GREEN
    fi
    
    # Copy main README
    if [ -f "$source_dir/README.md" ]; then
        cp "$source_dir/README.md" .
        files_copied=$((files_copied + 1))
        log "   ✅ README.md" $GREEN
    fi
    
    # Copy configuration files
    for config_file in template_config.yml requirements.txt setup.py pyproject.toml; do
        if [ -f "$source_dir/$config_file" ]; then
            cp "$source_dir/$config_file" .
            files_copied=$((files_copied + 1))
            log "   ✅ $config_file" $GREEN
        fi
    done
    
    # Handle .gitignore with validation
    if [ -f "$source_dir/.gitignore" ]; then
        # Check if .gitignore properly excludes private directories
        local missing_excludes=()
        for private_dir in src scripts data drafts etc share; do
            if ! grep -q "^${private_dir}/\s*$" "$source_dir/.gitignore" 2>/dev/null; then
                missing_excludes+=("$private_dir/")
            fi
        done
        
        if [ ${#missing_excludes[@]} -gt 0 ]; then
            log "⚠️  .gitignore missing exclusions: ${missing_excludes[*]}" $YELLOW
            read -p "Add missing exclusions to .gitignore? (y/n): " fix_gitignore
            if [[ "$fix_gitignore" == "y" ]]; then
                cp "$source_dir/.gitignore" .gitignore.tmp
                echo "" >> .gitignore.tmp
                echo "# Private development directories (added by $SCRIPT_NAME)" >> .gitignore.tmp
                printf '%s\n' "${missing_excludes[@]}" >> .gitignore.tmp
                mv .gitignore.tmp .gitignore
                log "   ✅ .gitignore (enhanced)" $GREEN
            else
                cp "$source_dir/.gitignore" .
                log "   ✅ .gitignore" $GREEN
            fi
        else
            cp "$source_dir/.gitignore" .
            log "   ✅ .gitignore" $GREEN
        fi
        files_copied=$((files_copied + 1))
    else
        # Create a comprehensive .gitignore for the public repo
        cat > .gitignore << 'EOF'
# Private development directories
src/
scripts/
data/
drafts/
etc/
share/

# Python
__pycache__/
*.py[cod]
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Jupyter
.ipynb_checkpoints
*/.ipynb_checkpoints/*

# Environment
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/
*.yml
!template_config.yml

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Logs and temp files
*.log
*.tmp
.tmp/

# Build artifacts
*.tar.gz
*.zip
EOF
        files_copied=$((files_copied + 1))
        log "   ✅ .gitignore (created comprehensive)" $GREEN
    fi
    
    log "📊 Total files copied: $files_copied" $BLUE
    return 0
}

# Main script
show_header() {
    echo ""
    log "╔══════════════════════════════════════════════════════════════════════════════╗" $BLUE
    log "║                         Repository Replacement Tool                          ║" $BLUE  
    log "║                                                                              ║" $BLUE
    log "║  Publishes: Documentation + Configuration only                              ║" $GREEN
    log "║  Private:   src/, scripts/, data/, drafts/ (stay local)                    ║" $YELLOW
    log "║  Version:   $SCRIPT_VERSION                                                     ║" $BLUE
    log "╚══════════════════════════════════════════════════════════════════════════════╝" $BLUE
    echo ""
}

show_header

validate_requirements
setup_git_auth

# Auto-detect default branch before cloning
log "🔍 Auto-detecting default branch..." $BLUE
DEFAULT_BRANCH=$(detect_default_branch "$REPO_URL")
log "✅ Detected default branch: $DEFAULT_BRANCH" $GREEN

# Clean up any existing work directories
if [ -d "$WORK_DIR" ]; then
    log "🧹 Removing existing work directory..." $YELLOW
    rm -rf "$WORK_DIR"
fi

get_local_directory

# Clone the existing repository with detected branch
log "📥 Cloning repository (branch: $DEFAULT_BRANCH)..." $BLUE
if ! git clone -b "$DEFAULT_BRANCH" "$REPO_URL" "$WORK_DIR"; then
    log "❌ Failed to clone branch '$DEFAULT_BRANCH'" $RED
    log "💡 This might be a new repository or the branch doesn't exist" $YELLOW
    
    # Try cloning without specifying branch
    log "🔄 Attempting to clone default branch..." $BLUE
    if git clone "$REPO_URL" "$WORK_DIR"; then
        cd "$WORK_DIR"
        DEFAULT_BRANCH=$(git branch --show-current)
        log "✅ Cloned with default branch: $DEFAULT_BRANCH" $GREEN
        cd ..
    else
        log "❌ Failed to clone repository" $RED
        exit 1
    fi
fi

# Create backup before making changes
log "🛡️  Creating safety backup..." $BLUE
cp -r "$WORK_DIR" "$BACKUP_DIR"
log "✅ Backup created: $BACKUP_DIR" $GREEN

cd "$WORK_DIR"

# Verify we're on the correct branch
CURRENT_BRANCH=$(git branch --show-current)
VERSION_TAG=$(get_version_tag)
log "✅ Repository ready - Branch: $CURRENT_BRANCH | Version: $VERSION_TAG" $GREEN

# Show current public content
log "📊 Current public repository:" $BLUE
find . -maxdepth 2 -type f -name "*.md" -o -name "*.yml" -o -name "*.txt" | head -10

# Clear out all content except .git
log "🧹 Clearing old content..." $YELLOW
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null || true

# Copy only public files
copy_public_files "$LOCAL_DIR"

# Create a project structure documentation
cat > STRUCTURE.md << 'EOF'
# Project Structure

This repository contains the public documentation and configuration for the Time Series Analysis project.

## Public Components
- `notebooks/` - Documentation and structure overview (READMEs)
- `README.md` - Main project documentation
- `template_config.yml` - Configuration template
- `.gitignore` - Git ignore rules

## Private Development
The following components remain in private development:
- `src/` - Python package modules
- `scripts/` - Utility scripts
- `data/` - Dataset files
- `drafts/` - Development notebooks

## Usage
This repository serves as the public face of the project. For collaboration on the full codebase, please contact the maintainer.
EOF

log "   ✅ STRUCTURE.md (created)" $GREEN

# Show what we're about to publish with size info
log "🔍 Public repository content:" $BLUE
find . -type f ! -path './.git/*' | sort
total_size=$(du -sh . 2>/dev/null | cut -f1)
log "📊 Total repository size: $total_size" $BLUE

# Check if there are changes
if [ -z "$(git status --porcelain)" ]; then
    log "ℹ️  Repository already up to date" $YELLOW
    cd .. && rm -rf "$WORK_DIR"
    exit 0
fi

# Show summary
public_files=$(find . -type f ! -path './.git/*' | wc -l)
readme_files=$(find . -name "README.md" | wc -l)

log "📊 Publication summary:" $GREEN
echo "   📄 Public files: $public_files"
echo "   📋 Documentation files: $readme_files"
echo "   🏷️  Version tag: $VERSION_TAG"
echo ""
echo "   📂 Public structure:"
echo "   ├── 📔 notebooks/ (READMEs + structure)"
echo "   ├── 📄 README.md (main documentation)"
echo "   ├── ⚙️  template_config.yml (configuration)"
echo "   ├── 🔒 .gitignore (privacy rules)"
echo "   └── 📋 STRUCTURE.md (project overview)"
echo ""

# Commit message options
echo "💬 Commit message options:"
echo "1. Documentation update v$VERSION_TAG"
echo "2. Project structure documentation v$VERSION_TAG"
echo "3. Configuration and README updates v$VERSION_TAG"
echo "4. Custom message"
echo ""

read -p "Choose option (1-4) or press Enter for option 1: " msg_choice
case "${msg_choice:-1}" in
    1) COMMIT_MESSAGE="Documentation update v$VERSION_TAG" ;;
    2) COMMIT_MESSAGE="Project structure documentation v$VERSION_TAG" ;;
    3) COMMIT_MESSAGE="Configuration and README updates v$VERSION_TAG" ;;
    4) 
        read -p "Enter custom commit message: " custom_msg
        COMMIT_MESSAGE="${custom_msg} v$VERSION_TAG"
        ;;
    *) COMMIT_MESSAGE="Documentation update v$VERSION_TAG" ;;
esac

echo ""
log "🚀 Ready to publish minimal repository:" $YELLOW
echo "   Repository: $REPO_URL"
echo "   Branch: $CURRENT_BRANCH"
echo "   Version: $VERSION_TAG"
echo "   Commit: $COMMIT_MESSAGE"
echo "   Backup: $BACKUP_DIR"
echo ""
log "   🔒 Private components remain local:" $BLUE
echo "   • src/ • scripts/ • data/ • drafts/"
echo ""

read -p "Publish documentation-only repository? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    log "❌ Publication cancelled" $YELLOW
    log "🛡️  Backup preserved: $BACKUP_DIR" $GREEN
    exit 1
fi

# Stage all changes
log "✅ Staging public content..." $GREEN
git add -A

# Commit the changes
log "✅ Creating commit..." $GREEN
git commit -m "$COMMIT_MESSAGE"

# Create version tag
log "🏷️  Creating version tag..." $GREEN
git tag -a "$VERSION_TAG" -m "$COMMIT_MESSAGE"

# Push changes and tags
log "📤 Publishing to GitHub..." $GREEN
if ! git push origin "$CURRENT_BRANCH"; then
    log "❌ Push failed. Check your GitHub token/credentials" $RED
    log "💡 Try setting GITHUB_TOKEN environment variable" $BLUE
    exit 1
fi

if ! git push origin "$VERSION_TAG"; then
    log "⚠️  Tag push failed, but commit was successful" $YELLOW
else
    log "✅ Version tag pushed successfully" $GREEN
fi

# Success summary
log "🎉 Publication successful!" $GREEN
echo ""
echo "✅ Repository: $REPO_URL"
echo "✅ Documentation published: $VERSION_TAG"
echo "✅ Commit: $(git rev-parse --short HEAD)"
echo "✅ Backup preserved: $BACKUP_DIR"
echo ""
echo "🔗 View at: ${REPO_URL/\.git/}/releases/tag/$VERSION_TAG"
echo ""

# Cleanup options
echo "🧹 Cleanup options:"
echo "1. Remove work directory only"
echo "2. Remove work directory and backup"
echo "3. Keep both (manual cleanup)"
read -p "Choose (1-3): " cleanup_choice

case "$cleanup_choice" in
    1)
        cd .. && rm -rf "$WORK_DIR"
        log "✅ Work directory cleaned" $GREEN
        log "🛡️  Backup preserved: $BACKUP_DIR" $YELLOW
        ;;
    2)
        log "⚠️  Are you sure you want to delete the backup?" $YELLOW
        read -p "This cannot be undone (y/n): " backup_confirm
        if [[ "$backup_confirm" == "y" ]]; then
            cd .. && rm -rf "$WORK_DIR" "$BACKUP_DIR"
            log "✅ All temporary files cleaned" $GREEN
        else
            cd .. && rm -rf "$WORK_DIR"
            log "✅ Work directory cleaned, backup preserved" $GREEN
        fi
        ;;
    3)
        log "📁 Manual cleanup required:" $YELLOW
        echo "   Work directory: $(pwd)"
        echo "   Backup: $BACKUP_DIR"
        ;;
esac

log "✨ Minimal repository published!" $GREEN
log "🔒 Your development work remains private and secure" $BLUE
echo ""
log "📋 Summary:" $GREEN
echo "   • Repository: $(basename "$REPO_URL" .git)"
echo "   • Version: $VERSION_TAG" 
echo "   • Branch: $CURRENT_BRANCH"
echo "   • Public files only (private code stays local)"
echo ""
log "💡 Next steps:" $BLUE
echo "   • Continue development in your local environment"
echo "   • Run this script again when you update documentation"
echo "   • Your private src/, scripts/, data/ remain untouched"
