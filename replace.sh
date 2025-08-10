#!/bin/bash

# GitHub Repository Replacement Script with Branch Detection
set -euo pipefail

# Configuration
REPO_URL="https://github.com/ArnaudDavyMM/Time_Series_Analysis.git"
LOCAL_SOURCE="$HOME/Desktop/Time_Series_Analysis/notebooks"
GITHUB_WORKDIR="github_repo_temp"
CURRENT_DATE=$(date +%Y-%m-%d)

# Detect default branch
get_default_branch() {
    git remote show origin | grep "HEAD branch" | awk '{print $3}'
}

# Versioning
get_next_version() {
    git fetch --tags 2>/dev/null || true
    last_version=$(git tag -l "v$CURRENT_DATE.*" | sort -V | tail -1)
    [[ -z "$last_version" ]] && echo "v$CURRENT_DATE.1" || {
        last_num=${last_version##*.}
        echo "v$CURRENT_DATE.$((last_num + 1))"
    }
}

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${2:-$NC}$1${NC}"; }

# --- Execution ---

# 1. Clone GitHub repo (detect default branch)
log "🌐 Cloning repository..." $GREEN
git clone "$REPO_URL" "$GITHUB_WORKDIR" || { log "❌ Clone failed" $RED; exit 1; }
cd "$GITHUB_WORKDIR"

BRANCH=$(get_default_branch)
log "🔍 Detected default branch: $BRANCH" $YELLOW

# 2. Get version and clean repo
VERSION=$(get_next_version)
log "🔄 Preparing version $VERSION" $GREEN

# 3. Wipe existing content (except .git)
find . -mindepth 1 ! -name '.git' -delete 2>/dev/null || true

# 4. Copy new structure
mkdir -p Time_Series_Analysis/notebooks
cp -r "$LOCAL_SOURCE/"* Time_Series_Analysis/notebooks/ || {
    log "❌ Failed to copy notebooks" $RED
    exit 1
}

# 5. Create essential files
cat > Time_Series_Analysis/README.md <<EOF
# Time Series Analysis ($VERSION)

## Public Structure
- notebooks/
  - exploratory_analysis/
  - model_evaluation/
  - model_training/
  - results_visualization/
EOF

cat > Time_Series_Analysis/.gitignore <<'EOF'
# Standard exclusions
.DS_Store
__pycache__/
*.swp

# Data exclusions
/data/
/config/
EOF

# 6. Commit and push
git add -A
if git commit -m "Complete replacement: $VERSION"; then
    git tag -a "$VERSION" -m "Version $VERSION"
    git push origin "$BRANCH" --force --tags
    log "✅ Successfully pushed to $BRANCH branch" $GREEN
    log "   Version: $VERSION" $GREEN
else
    log "⚠️ No changes to commit" $YELLOW
fi

# 7. Cleanup
cd ..
rm -rf "$GITHUB_WORKDIR"
