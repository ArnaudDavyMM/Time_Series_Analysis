#!/bin/bash

# GitHub Repository Replacement Script (Custom Branch)
set -euo pipefail

# Configuration
REPO_URL="https://github.com/ArnaudDavyMM/Time_Series_Analysis.git"
LOCAL_SOURCE="$HOME/Desktop/Time_Series_Analysis/notebooks"  # Your NEW notebooks
GITHUB_WORKDIR="github_repo_temp"  # Temporary clone
BRANCH="master"  # Your custom branch name
CURRENT_DATE=$(date +%Y-%m-%d)

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
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${2:-$NC}$1${NC}"; }

# --- Execution ---

# 1. Clone GitHub repo (specific branch)
git clone -b "$BRANCH" "$REPO_URL" "$GITHUB_WORKDIR" || {
    log "❌ Clone failed (does branch '$BRANCH' exist?)" $RED
    exit 1
}
cd "$GITHUB_WORKDIR"

# 2. Get version and clean repo
VERSION=$(get_next_version)
log "🔄 Replacing GitHub repo ($BRANCH branch) with version $VERSION" $GREEN

# 3. WIPE existing content (except .git)
find . -mindepth 1 ! -name '.git' -delete 2>/dev/null || true

# 4. Copy ONLY public structure
mkdir -p Time_Series_Analysis/notebooks
cp -r "$LOCAL_SOURCE/"* Time_Series_Analysis/notebooks/ || {
    log "❌ Failed to copy notebooks" $RED
    exit 1
}

# 5. Add mandatory files
cat > Time_Series_Analysis/README.md <<EOF
# Time Series Analysis ($VERSION)

## Public Components
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

# Data/code exclusions
/data/
/config/
EOF

# 6. Commit and FORCE push
git add -A
if git commit -m "COMPLETE REPLACEMENT: $VERSION"; then
    git tag -a "$VERSION" -m "Version $VERSION"
    git push origin "$BRANCH" --force --tags
    log "✅ GitHub repo '$BRANCH' branch replaced!" $GREEN
    log "   Version: $VERSION" $GREEN
    log "   Source: $LOCAL_SOURCE" $GREEN
else
    log "⚠️ No changes detected" $GREEN
fi

# 7. Cleanup
cd ..
rm -rf "$GITHUB_WORKDIR"
