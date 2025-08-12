#!/bin/bash

# Enhanced publishing script for Jupyter notebooks and visualizations
# Single category per commit with rock-solid HTML generation

set -e  # Exit on any error

# Configuration
DRAFTS_DIR="drafts"
NOTEBOOKS_DIR="notebooks"
DOCS_DIR="docs"
README_GENERATOR="generate_readme.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${PURPLE}✨ $1${NC}"
}

# Function to detect category from file path
detect_category() {
    local filepath="$1"
    
    # Remove drafts/ prefix and extract category
    local path_without_drafts="${filepath#$DRAFTS_DIR/}"
    
    # Extract the first directory component as category
    local category=$(echo "$path_without_drafts" | cut -d'/' -f1)
    
    # Validate category
    case "$category" in
        "exploratory_analysis"|"model_training"|"model_evaluation"|"results_visualization")
            echo "$category"
            ;;
        *)
            echo "exploratory_analysis"  # Default category
            ;;
    esac
}

# Function to find all publishable files grouped by category
find_publishable_files_by_category() {
    print_status "Scanning for publishable files..."
    
    declare -A category_files
    
    # Find all .ipynb files in drafts
    while IFS= read -r -d '' file; do
        local category=$(detect_category "$file")
        if [[ -z "${category_files[$category]}" ]]; then
            category_files[$category]="$file"
        else
            category_files[$category]="${category_files[$category]}|$file"
        fi
    done < <(find "$DRAFTS_DIR" -name "*.ipynb" -print0 2>/dev/null || true)
    
    # Find all .html and .svg files in drafts (visualizations)
    while IFS= read -r -d '' file; do
        local category=$(detect_category "$file")
        if [[ -z "${category_files[$category]}" ]]; then
            category_files[$category]="$file"
        else
            category_files[$category]="${category_files[$category]}|$file"
        fi
    done < <(find "$DRAFTS_DIR" -name "*.html" -o -name "*.svg" -print0 2>/dev/null || true)
    
    # Output category groups
    for category in "${!category_files[@]}"; do
        echo "CATEGORY:$category"
        IFS='|' read -ra files <<< "${category_files[$category]}"
        for file in "${files[@]}"; do
            echo "FILE:$file"
        done
    done
}

# Function to list available files grouped by category
list_files() {
    print_header "Available files for publishing (grouped by category)"
    
    local category_data=($(find_publishable_files_by_category))
    
    if [ ${#category_data[@]} -eq 0 ]; then
        print_warning "No publishable files found in $DRAFTS_DIR/"
        exit 0
    fi
    
    local total_categories=0
    local current_category=""
    local category_index=1
    
    for item in "${category_data[@]}"; do
        if [[ $item == CATEGORY:* ]]; then
            current_category="${item#CATEGORY:}"
            echo ""
            echo -e "${BLUE}[$category_index] Category: $current_category${NC}"
            ((category_index++))
            ((total_categories++))
        elif [[ $item == FILE:* ]]; then
            local file="${item#FILE:}"
            local basename=$(basename "$file")
            echo "    → $basename"
        fi
    done
    
    echo ""
    echo "Total: $total_categories categories available"
    echo -e "${YELLOW}Note: Each category will be published as a separate commit${NC}"
}

# Function to convert notebook to HTML with rock-solid Plotly support
convert_notebook_to_html() {
    local notebook_path="$1"
    local output_dir="$2"
    local basename=$(basename "$notebook_path" .ipynb)
    local html_output="$output_dir/${basename}.html"
    
    print_status "🌐 Converting $basename.ipynb to HTML with Plotly support..."
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Try lab template first (best for Plotly and interactive content)
    if command -v jupyter &> /dev/null; then
        if jupyter nbconvert \
            --to html \
            --template lab \
            --TagRemovePreprocessor.enabled=True \
            --TagRemovePreprocessor.remove_cell_tags='["remove_cell"]' \
            --output-dir "$output_dir" \
            "$notebook_path" 2>/dev/null; then
            
            print_status "✅ HTML generated with lab template"
            
            # Post-process to ensure rock-solid Plotly support
            if [[ -f "$html_output" ]]; then
                print_status "🔧 Applying Plotly fixes for GitHub Pages..."
                
                # Fix Plotly CDN to stable version
                sed -i 's|https://cdn.plot.ly/plotly-latest.min.js|https://cdn.plot.ly/plotly-2.26.0.min.js|g' "$html_output" 2>/dev/null || true
                
                # Ensure proper viewport meta tag for mobile
                if ! grep -q "viewport" "$html_output"; then
                    sed -i 's|<head>|<head>\n    <meta name="viewport" content="width=device-width, initial-scale=1.0">|' "$html_output" 2>/dev/null || true
                fi
                
                # Add responsive CSS for better display
                sed -i 's|</head>|    <style>\n        .jp-RenderedHTMLCommon { max-width: 100% !important; }\n        .plotly-graph-div { width: 100% !important; height: auto !important; }\n    </style>\n</head>|' "$html_output" 2>/dev/null || true
                
                print_success "🎯 HTML optimized for GitHub Pages with perfect Plotly support"
            fi
        else
            print_warning "⚠️  Lab template failed, trying basic template..."
            jupyter nbconvert \
                --to html \
                --output-dir "$output_dir" \
                "$notebook_path"
            print_status "✅ HTML generated with basic template"
        fi
    else
        print_error "Jupyter not found. Please install jupyter: pip install jupyter"
        return 1
    fi
    
    if [ -f "$html_output" ]; then
        print_status "📄 HTML documentation: $html_output"
        return 0
    else
        print_error "Failed to create HTML output"
        return 1
    fi
}

# Function to get next version number for today
get_next_version() {
    local today=$(date '+%Y-%m-%d')
    local version_pattern="v${today}\\."
    
    # Get the highest version number for today
    local highest_version=$(git tag -l "${version_pattern}*" 2>/dev/null | \
                           sed "s/v${today}\\.//g" | \
                           sort -n | \
                           tail -1)
    
    if [ -z "$highest_version" ]; then
        echo "v${today}.1"
    else
        echo "v${today}.$((highest_version + 1))"
    fi
}

# Function to get semantic commit type based on category
get_commit_type_for_category() {
    local category="$1"
    local files=("${@:2}")
    
    case "$category" in
        "exploratory_analysis")
            echo "feat"  # New analysis features
            ;;
        "model_training")
            echo "model"  # Model training/experiments
            ;;
        "model_evaluation") 
            echo "model"  # Model evaluation
            ;;
        "results_visualization")
            # Check if files are mostly visualizations
            local viz_count=0
            for file in "${files[@]}"; do
                if [[ "$file" == *.html ]] || [[ "$file" == *.svg ]]; then
                    ((viz_count++))
                fi
            done
            if [ $viz_count -gt 0 ]; then
                echo "viz"
            else
                echo "feat"
            fi
            ;;
        *)
            echo "feat"
            ;;
    esac
}

# Function to get smart default message
get_default_message() {
    local category="$1"
    local files=("${@:2}")
    local file_count=${#files[@]}
    
    case "$category" in
        "exploratory_analysis")
            if [ $file_count -eq 1 ]; then
                echo "Add exploratory data analysis"
            else
                echo "Add $file_count exploratory analyses"
            fi
            ;;
        "model_training")
            if [ $file_count -eq 1 ]; then
                echo "Add model training notebook"
            else
                echo "Add $file_count model training notebooks"
            fi
            ;;
        "model_evaluation")
            if [ $file_count -eq 1 ]; then
                echo "Add model evaluation analysis"
            else
                echo "Add $file_count model evaluations"
            fi
            ;;
        "results_visualization")
            local viz_count=0
            for file in "${files[@]}"; do
                if [[ "$file" == *.html ]] || [[ "$file" == *.svg ]]; then
                    ((viz_count++))
                fi
            done
            if [ $viz_count -gt 0 ]; then
                if [ $viz_count -eq 1 ]; then
                    echo "Add new visualization"
                else
                    echo "Add $viz_count new visualizations"
                fi
            else
                echo "Add visualization notebooks"
            fi
            ;;
        *)
            echo "Add notebook analysis"
            ;;
    esac
}

# Function to publish files in a category
publish_category() {
    local category="$1"
    local files=("${@:2}")
    
    print_header "Publishing Category: $category (${#files[@]} files)"
    
    # Create target directory
    local target_dir="$NOTEBOOKS_DIR/$category"
    mkdir -p "$target_dir"
    
    local published_files=()
    
    # Process each file
    for source_file in "${files[@]}"; do
        local basename=$(basename "$source_file")
        local extension="${basename##*.}"
        
        print_status "📝 Processing: $basename"
        
        case "$extension" in
            "ipynb")
                # Handle Jupyter notebooks
                local target_file="$target_dir/$basename"
                
                # Copy notebook
                cp "$source_file" "$target_file"
                print_status "✅ Copied notebook: $basename"
                
                # Convert to HTML in docs directory
                mkdir -p "$DOCS_DIR"
                if convert_notebook_to_html "$target_file" "$DOCS_DIR"; then
                    print_status "📚 HTML documentation created"
                fi
                
                published_files+=("$basename")
                ;;
                
            "html"|"svg")
                # Handle visualization files - these go to results_visualization
                local viz_target_dir="$NOTEBOOKS_DIR/results_visualization"
                mkdir -p "$viz_target_dir"
                local target_file="$viz_target_dir/$basename"
                
                cp "$source_file" "$target_file"
                print_status "✅ Copied visualization: $basename"
                published_files+=("$basename")
                ;;
                
            *)
                print_warning "Unknown file type: $extension, copying to $category directory"
                local target_file="$target_dir/$basename"
                cp "$source_file" "$target_file"
                published_files+=("$basename")
                ;;
        esac
    done
    
    # Update README for this category
    update_readme_for_category "$category"
    
    # Commit this category
    commit_category "$category" "${files[@]}"
    
    print_success "🎉 Category '$category' published successfully!"
    return 0
}

# Function to update README for specific category
update_readme_for_category() {
    local category="$1"
    
    print_status "📖 Updating README for $category..."
    
    if [ -f "$README_GENERATOR" ] && [ -x "$README_GENERATOR" ]; then
        if python3 "$README_GENERATOR"; then
            print_status "✅ README files updated"
        else
            print_warning "README generator failed, but continuing..."
        fi
    else
        print_warning "README generator not found or not executable: $README_GENERATOR"
    fi
}

# Function to commit a specific category
commit_category() {
    local category="$1"
    local files=("${@:2}")
    
    print_status "💾 Committing category: $category"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_warning "Not in a git repository, skipping git operations"
        return 0
    fi
    
    # Add all changes
    git add .
    
    # Check if there are any changes to commit
    if git diff --cached --quiet; then
        print_status "No changes to commit for $category"
        return 0
    fi
    
    # Get next version number
    local version=$(get_next_version)
    print_status "🏷️  Creating version: $version"
    
    # Get suggested commit type and message
    local suggested_type=$(get_commit_type_for_category "$category" "${files[@]}")
    local default_msg=$(get_default_message "$category" "${files[@]}")
    
    # Semantic commit workflow
    echo ""
    echo -e "${BLUE}📝 Commit for category: $category${NC}"
    echo -e "${YELLOW}💡 Suggested type: '$suggested_type'${NC}"
    echo ""
    echo "Choose commit type:"
    echo "  1) feat     → New analysis or major feature"
    echo "  2) data     → Data processing, cleaning, or new datasets"
    echo "  3) model    → Model training, tuning, or experiments"
    echo "  4) viz      → New visualizations or charts"
    echo "  5) docs     → Documentation or README updates"
    echo "  6) refactor → Code restructuring or optimization"
    echo "  7) fix      → Bug fixes or corrections"
    echo "  8) perf     → Performance improvements"
    echo "  9) test     → Adding or updating tests/validation"
    echo " 10) chore    → Maintenance, deps, or cleanup"
    
    # Auto-select based on suggested type
    local default_choice=1
    case "$suggested_type" in
        "data") default_choice=2 ;;
        "model") default_choice=3 ;;
        "viz") default_choice=4 ;;
        "docs") default_choice=5 ;;
        "refactor") default_choice=6 ;;
        "fix") default_choice=7 ;;
        "perf") default_choice=8 ;;
        "test") default_choice=9 ;;
        "chore") default_choice=10 ;;
        *) default_choice=1 ;;
    esac
    
    read -p "Enter number [default: $default_choice]: " commit_type_choice
    commit_type_choice=${commit_type_choice:-$default_choice}
    
    case "$commit_type_choice" in
        2) commit_type="data" ;;
        3) commit_type="model" ;;
        4) commit_type="viz" ;;
        5) commit_type="docs" ;;
        6) commit_type="refactor" ;;
        7) commit_type="fix" ;;
        8) commit_type="perf" ;;
        9) commit_type="test" ;;
        10) commit_type="chore" ;;
        *) commit_type="feat" ;;
    esac
    
    # Get custom message or use default
    read -p "Enter description [default: $default_msg]: " custom_msg
    local final_msg=${custom_msg:-$default_msg}
    
    # Create semantic commit message
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local commit_message="$commit_type: $final_msg

Category: $category
Version: $version
Published: $timestamp

Files published:"
    
    # Add list of published files to commit message
    for file in "${files[@]}"; do
        local basename=$(basename "$file")
        commit_message="$commit_message
- $basename"
    done
    
    # Commit changes
    if git commit -m "$commit_message"; then
        print_status "✅ Committed with type: $commit_type"
        
        # Create annotated tag
        local tag_message="$version - $commit_type: $final_msg"
        if git tag -a "$version" -m "$tag_message"; then
            print_status "🏷️  Created tag: $version"
        else
            print_warning "Failed to create tag, but commit was successful"
        fi
        
        # Push to remote with tags
        print_status "🚀 Pushing to GitHub..."
        if git push && git push --tags; then
            print_success "🎉 Version $version pushed successfully to GitHub!"
        else
            print_error "Failed to push to GitHub"
            print_status "Manual push needed: git push && git push --tags"
            return 1
        fi
    else
        print_error "Failed to commit changes"
        return 1
    fi
}

# Function to publish selected categories
publish_categories() {
    local category_data=($(find_publishable_files_by_category))
    
    if [ ${#category_data[@]} -eq 0 ]; then
        print_warning "No publishable files found"
        exit 0
    fi
    
    # Parse categories and files
    declare -A categories
    local current_category=""
    
    for item in "${category_data[@]}"; do
        if [[ $item == CATEGORY:* ]]; then
            current_category="${item#CATEGORY:}"
            categories[$current_category]=""
        elif [[ $item == FILE:* ]]; then
            local file="${item#FILE:}"
            if [[ -z "${categories[$current_category]}" ]]; then
                categories[$current_category]="$file"
            else
                categories[$current_category]="${categories[$current_category]}|$file"
            fi
        fi
    done
    
    # Show categories
    print_header "Select categories to publish"
    echo -e "${YELLOW}Each category will be published as a separate commit${NC}"
    echo ""
    
    local category_list=()
    local index=1
    for category in $(printf '%s\n' "${!categories[@]}" | sort); do
        category_list+=("$category")
        IFS='|' read -ra files <<< "${categories[$category]}"
        echo "[$index] $category (${#files[@]} files)"
        for file in "${files[@]}"; do
            echo "    → $(basename "$file")"
        done
        ((index++))
        echo ""
    done
    
    echo "Enter category numbers to publish (space-separated, 'all' for all, or 'q' to quit):"
    read -r selection
    
    case "$selection" in
        "q"|"quit"|"exit")
            print_status "Cancelled by user"
            exit 0
            ;;
        "all"|"*")
            print_status "Publishing all categories..."
            selected_categories=("${category_list[@]}")
            ;;
        *)
            # Parse individual selections
            selected_categories=()
            for num in $selection; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#category_list[@]}" ]; then
                    selected_categories+=("${category_list[$((num-1))]}")
                else
                    print_warning "Invalid selection: $num"
                fi
            done
            ;;
    esac
    
    if [ ${#selected_categories[@]} -eq 0 ]; then
        print_warning "No valid categories selected"
        exit 0
    fi
    
    # Publish each selected category
    print_header "Publishing ${#selected_categories[@]} categories"
    
    for category in "${selected_categories[@]}"; do
        IFS='|' read -ra files <<< "${categories[$category]}"
        publish_category "$category" "${files[@]}"
        echo ""
    done
    
    print_header "🎉 All selected categories published successfully!"
    print_status "🔗 Check your GitHub repository for the updates"
}

# Main script logic
main() {
    # Check if required directories exist
    if [ ! -d "$DRAFTS_DIR" ]; then
        print_error "Drafts directory not found: $DRAFTS_DIR"
        exit 1
    fi
    
    # Create target directories if they don't exist
    mkdir -p "$NOTEBOOKS_DIR"
    mkdir -p "$DOCS_DIR"
    
    # Parse command line arguments
    case "${1:-}" in
        "--list"|"-l")
            list_files
            ;;
        "--help"|"-h")
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Single Category Publishing Script"
            echo "================================="
            echo "Publishes notebooks by category with semantic commits and rock-solid HTML generation"
            echo ""
            echo "Options:"
            echo "  --list, -l     List available files grouped by category"
            echo "  --help, -h     Show this help message"
            echo ""
            echo "Features:"
            echo "  • Single category per commit for clean git history"
            echo "  • Automatic daily versioning (v2025-08-11.1, v2025-08-11.2, etc.)"
            echo "  • Rock-solid HTML generation with perfect Plotly support"
            echo "  • Semantic commit types (feat, model, viz, etc.)"
            echo "  • Automatic README updates"
            echo "  • Smart suggestions based on file content"
            echo ""
            echo "Interactive mode (default): Select and publish categories"
            ;;
        *)
            publish_categories
            ;;
    esac
}

# Run main function
main "$@"
