#!/bin/bash

# Colors for display
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

set -e

# List available drafts
list_drafts() {
    echo -e "${BLUE}Available draft notebooks:${NC}"
    find drafts -name "*.ipynb" -type f | sort | nl -w2 -s') '
}

# Interactive selection
interactive_select() {
    list_drafts
    echo ""
    read -p "Enter the number of the notebook to publish: " selection
    
    selected_file=$(find drafts -name "*.ipynb" -type f | sort | sed -n "${selection}p")
    
    if [[ -z "$selected_file" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        exit 1
    fi
    
    echo "$selected_file"
}

# Find notebook by partial name
find_by_name() {
    local name="$1"
    local matches=($(find drafts -name "*${name}*" -type f))
    
    if [[ ${#matches[@]} -eq 0 ]]; then
        echo -e "${RED}No notebooks found matching: $name${NC}"
        exit 1
    elif [[ ${#matches[@]} -eq 1 ]]; then
        echo "${matches[0]}"
    else
        echo -e "${YELLOW}Multiple matches found:${NC}"
        printf '%s\n' "${matches[@]}" | nl -w2 -s') '
        echo ""
        read -p "Enter the number of your choice: " choice
        selected=$(printf '%s\n' "${matches[@]}" | sed -n "${choice}p")
        if [[ -z "$selected" ]]; then
            echo -e "${RED}Invalid choice!${NC}"
            exit 1
        fi
        echo "$selected"
    fi
}

# Main publishing function
publish_notebook() {
    local draft_path="$1"
    
    if [[ ! -f "$draft_path" ]]; then
        echo -e "${RED}File not found: $draft_path${NC}"
        exit 1
    fi
    
    # Extract category and filename from draft path
    local category=$(dirname "$draft_path" | sed 's/drafts\///')
    local notebook_name=$(basename "$draft_path")
    local notebook_base="${notebook_name%.ipynb}"
    
    # Define paths
    local public_dir="notebooks/$category"
    local public_path="$public_dir/$notebook_name"
    local docs_dir="docs"
    local html_path="$docs_dir/${notebook_base}.html"
    
    echo -e "${BLUE}Publishing notebook: $notebook_name${NC}"
    echo "  From: $draft_path"
    echo "  To:   $public_path"
    echo "  HTML: $html_path"
    
    # Create directories if they don't exist
    mkdir -p "$public_dir"
    mkdir -p "$docs_dir"
    
    # Clear outputs from draft (keep original clean)
    echo -e "${YELLOW}Clearing notebook outputs...${NC}"
    jupyter nbconvert --clear-output --inplace "$draft_path"
    
    # Copy to public area
    echo -e "${YELLOW}Copying to public directory...${NC}"
    cp "$draft_path" "$public_path"
    
    # Generate HTML version with lab template
    echo -e "${YELLOW}Generating HTML with perfect Plotly support...${NC}"
    jupyter nbconvert "$public_path" --to html --template lab --output-dir "$docs_dir"
    
    echo -e "${GREEN}✓ Notebook published successfully!${NC}"
    echo -e "${GREEN}✓ HTML version created: $html_path${NC}"
    
    return 0
}

# Main execution logic
main() {
    echo -e "${BLUE}=== Time Series Analysis Notebook Publisher ===${NC}"
    
    local draft_notebook=""
    
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        draft_notebook=$(interactive_select)
    elif [[ "$1" == "--list" || "$1" == "-l" ]]; then
        list_drafts
        exit 0
    else
        # Command line argument
        if [[ -f "$1" ]]; then
            draft_notebook="$1"
        else
            # Search by partial name
            draft_notebook=$(find_by_name "$1")
        fi
    fi
    
    # Publish the notebook
    publish_notebook "$draft_notebook"
    
    # Extract notebook info for git operations
    local category=$(dirname "$draft_notebook" | sed 's/drafts\///')
    local notebook_name=$(basename "$draft_notebook")
    local notebook_base="${notebook_name%.ipynb}"
    local public_path="notebooks/$category/$notebook_name"
    local html_path="docs/${notebook_base}.html"
    
    # Semantic commit workflow
    echo ""
    echo -e "${BLUE}Choose commit type:${NC}"
    echo "  1) feat     → New analysis or major feature"
    echo "  2) docs     → Documentation update"
    echo "  3) refactor → Restructuring existing analysis"
    echo "  4) fix      → Bug fix or correction"
    echo "  5) chore    → Maintenance or cleanup"
    read -p "Enter number [default: 1]: " commit_type_choice
    
    case "$commit_type_choice" in
        2) commit_type="docs" ;;
        3) commit_type="refactor" ;;
        4) commit_type="fix" ;;
        5) commit_type="chore" ;;
        *) commit_type="feat" ;;
    esac
    
    # Get changelog summary
    read -p "Enter changelog summary [default: Add $notebook_base analysis]: " changelog
    changelog=${changelog:-"Add $notebook_base analysis"}
    
    # Generate version tag
    local today=$(date +"%Y%m%d")
    local version_tag="v${today}-${notebook_base}"
    local commit_message="$commit_type: $changelog"
    
    # Display git commands
    echo ""
    echo -e "${GREEN}📋 Files ready for commit:${NC}"
    echo "  📓 Notebook: $public_path"
    echo "  🌐 HTML: $html_path"
    echo ""
    
    # Ask if user wants to update README files
    read -p "Update README files? [y/N]: " update_readme
    if [[ "$update_readme" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Updating README files...${NC}"
        python generate_readme.py
        echo -e "${GREEN}✓ README files updated${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🚀 Git commands to run:${NC}"
    if [[ "$update_readme" =~ ^[Yy]$ ]]; then
        echo "  git add \"$public_path\" \"$html_path\" \"notebooks/$category/README.md\" \"NOTEBOOKS_README.md\""
        echo "  git commit -m \"$commit_message + update README\""
    else
        echo "  git add \"$public_path\" \"$html_path\""
        echo "  git commit -m \"$commit_message\""
    fi
    echo "  git tag $version_tag"
    echo "  git push && git push origin $version_tag"
    echo ""
    echo -e "${YELLOW}💡 Your HTML file will be at: docs/${notebook_base}.html${NC}"
}

# Run main function
main "$@"
