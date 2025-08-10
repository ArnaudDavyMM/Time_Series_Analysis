#!/usr/bin/env python3
"""
Enhanced README Generator for Time Series Analysis Project
Generates README files for notebook directories with HTML links and better metadata extraction.
"""

import os
import nbformat
from datetime import datetime
from pathlib import Path
import json
import sys

# Enhanced folder structure with your actual categories
folder_info = {
    "exploratory_analysis": {
        "title": "🧭 Exploratory Analysis",
        "description": "Initial data exploration and feature engineering using retail sales time series data.",
        "objectives": [
            "Perform comprehensive data quality checks and profiling",
            "Identify temporal patterns, trends, and seasonality",
            "Engineer features for time series forecasting models"
        ]
    },
    "model_training": {
        "title": "🛠️ Model Training", 
        "description": "Building and refining time series forecasting models using statistical and ML techniques.",
        "objectives": [
            "Train Prophet and other forecasting models",
            "Optimize hyperparameters for best performance",
            "Implement cross-validation for time series data"
        ]
    },
    "model_evaluation": {
        "title": "📊 Model Evaluation",
        "description": "Comprehensive model assessment using forecasting metrics and diagnostic analysis.",
        "objectives": [
            "Compare models using MAPE, RMSE, and other forecasting metrics",
            "Analyze residuals and forecast accuracy patterns",
            "Select optimal model for production deployment"
        ]
    },
    "results_visualization": {
        "title": "📈 Results Visualization", 
        "description": "Interactive visualizations and dashboards for model results and business insights.",
        "objectives": [
            "Create interactive Plotly dashboards for stakeholders",
            "Visualize forecast results and confidence intervals",
            "Generate business-ready reports and presentations"
        ]
    }
}

def extract_notebook_metadata(notebook_path):
    """Extract comprehensive metadata from notebook including title and description."""
    metadata = {
        'title': os.path.basename(notebook_path).replace('.ipynb', '').replace('_', ' ').title(),
        'description': '',
        'has_plotly': False,
        'cell_count': 0,
        'markdown_cells': 0,
        'code_cells': 0
    }
    
    try:
        with open(notebook_path, 'r', encoding='utf-8') as f:
            nb = nbformat.read(f, as_version=4)
            
            # Count cells
            metadata['cell_count'] = len(nb.cells)
            metadata['code_cells'] = sum(1 for cell in nb.cells if cell.cell_type == 'code')
            metadata['markdown_cells'] = sum(1 for cell in nb.cells if cell.cell_type == 'markdown')
            
            # Extract title from first markdown cell or first heading
            for cell in nb.cells:
                if cell.cell_type == 'markdown' and cell.source.strip():
                    lines = cell.source.strip().split('\n')
                    for line in lines:
                        if line.startswith('#'):
                            metadata['title'] = line.strip('#').strip()
                            break
                    # Get description from remaining content
                    remaining_lines = [line for line in lines if not line.startswith('#') and line.strip()]
                    if remaining_lines:
                        metadata['description'] = remaining_lines[0][:100] + '...' if len(remaining_lines[0]) > 100 else remaining_lines[0]
                    break
            
            # Check for Plotly usage
            for cell in nb.cells:
                if cell.cell_type == 'code' and 'plotly' in cell.source.lower():
                    metadata['has_plotly'] = True
                    break
                    
    except Exception as e:
        print(f"Warning: Could not read notebook {notebook_path}: {e}")
        
    return metadata

def generate_notebook_links(notebook_file, folder):
    """Generate both GitHub and HTML links for a notebook."""
    base_name = notebook_file.replace('.ipynb', '')
    
    # GitHub notebook link (for code viewing)
    github_link = f"notebooks/{folder}/{notebook_file}"
    
    # HTML link (for perfect visualization)
    html_link = f"docs/{base_name}.html"
    
    return github_link, html_link

def generate_folder_readme(folder_path, folder_key):
    """Generate README for a specific notebook folder."""
    info = folder_info.get(folder_key)
    if not info:
        print(f"Warning: No info found for folder {folder_key}")
        return
        
    readme_lines = [
        f"# {info['title']}",
        "",
        info['description'],
        "",
        "## 📚 Notebooks",
        "",
        "| Notebook | Description | View Options | Last Updated |",
        "|----------|-------------|--------------|--------------|"
    ]
    
    # Process notebooks in folder
    notebooks_found = 0
    notebook_files = [f for f in os.listdir(folder_path) if f.endswith('.ipynb')]
    notebook_files.sort()  # Sort alphabetically
    
    for notebook_file in notebook_files:
        notebook_path = os.path.join(folder_path, notebook_file)
        metadata = extract_notebook_metadata(notebook_path)
        
        github_link, html_link = generate_notebook_links(notebook_file, folder_key)
        
        # Format last modified date
        modified_date = datetime.fromtimestamp(os.path.getmtime(notebook_path)).strftime('%Y-%m-%d')
        
        # Create view options with icons
        view_options = f"[📓 Code]({github_link})"
        if os.path.exists(f"docs/{notebook_file.replace('.ipynb', '.html')}"):
            view_options += f" • [🌐 HTML]({html_link})"
        if metadata['has_plotly']:
            view_options += " 📊"
            
        # Add to table
        readme_lines.append(
            f"| **{metadata['title']}** | {metadata['description'] or 'Analysis notebook'} | {view_options} | {modified_date} |"
        )
        notebooks_found += 1
    
    if notebooks_found == 0:
        readme_lines.append("| *No notebooks yet* | | | |")
    
    # Add objectives section
    readme_lines.extend([
        "",
        "## 🎯 Key Objectives",
        ""
    ])
    
    for objective in info['objectives']:
        readme_lines.append(f"- {objective}")
    
    # Add navigation
    readme_lines.extend([
        "",
        "## 🔗 Navigation",
        "",
        "- [← Back to Main Project](../README.md)",
        "- [📊 Interactive Results](../docs/) - HTML versions with perfect Plotly rendering",
        "",
        f"---",
        f"*Generated on {datetime.now().strftime('%Y-%m-%d %H:%M')}*"
    ])
    
    # Write README
    readme_path = os.path.join(folder_path, "README.md")
    with open(readme_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(readme_lines))
    
    print(f"✓ Generated README for {folder_key} ({notebooks_found} notebooks)")

def generate_main_readme():
    """Generate main project README with overview of all notebooks."""
    readme_lines = [
        "# 📊 Time Series Analysis - Notebook Overview",
        "",
        "Auto-generated overview of all analysis notebooks in this project.",
        "",
        "## 🎯 Quick Access - Interactive Results",
        "",
        "*Perfect for presentations and stakeholders - all plots are interactive:*",
        ""
    ]
    
    # Add HTML links for all notebooks across folders
    for folder_key in folder_info.keys():
        folder_path = os.path.join("notebooks", folder_key)
        if os.path.exists(folder_path):
            info = folder_info[folder_key]
            readme_lines.append(f"### {info['title']}")
            
            notebook_files = [f for f in os.listdir(folder_path) if f.endswith('.ipynb')]
            for notebook_file in sorted(notebook_files):
                notebook_path = os.path.join(folder_path, notebook_file)
                metadata = extract_notebook_metadata(notebook_path)
                
                html_file = notebook_file.replace('.ipynb', '.html')
                if os.path.exists(f"docs/{html_file}"):
                    readme_lines.append(f"- [📊 {metadata['title']}](docs/{html_file})")
                    
            readme_lines.append("")
    
    # Add technical section
    readme_lines.extend([
        "## 👨‍💻 Technical Notebooks",
        "",
        "*For developers and data scientists:*",
        ""
    ])
    
    for folder_key in folder_info.keys():
        folder_path = os.path.join("notebooks", folder_key)
        if os.path.exists(folder_path):
            info = folder_info[folder_key]
            readme_lines.append(f"### [{info['title']}](notebooks/{folder_key}/)")
            readme_lines.append(f"{info['description']}")
            readme_lines.append("")
    
    readme_lines.extend([
        f"---",
        f"*Auto-generated on {datetime.now().strftime('%Y-%m-%d %H:%M')} | Run `python generate_readme.py` to update*"
    ])
    
    # Write main README
    with open("NOTEBOOKS_README.md", 'w', encoding='utf-8') as f:
        f.write('\n'.join(readme_lines))
    
    print("✓ Generated main notebooks README")

def main():
    """Main execution function."""
    print("🚀 Generating README files for notebook directories...")
    
    base_notebooks_dir = "notebooks"
    
    if not os.path.exists(base_notebooks_dir):
        print(f"❌ Error: {base_notebooks_dir} directory not found!")
        sys.exit(1)
    
    # Generate README for each folder
    folders_processed = 0
    for folder_key in folder_info.keys():
        folder_path = os.path.join(base_notebooks_dir, folder_key)
        if os.path.exists(folder_path):
            generate_folder_readme(folder_path, folder_key)
            folders_processed += 1
        else:
            print(f"⚠️  Folder not found: {folder_path}")
    
    # Generate main overview README
    generate_main_readme()
    
    print(f"\n✅ Complete! Generated README files for {folders_processed} folders.")
    print("📝 Files created:")
    print("   - NOTEBOOKS_README.md (main overview)")
    for folder_key in folder_info.keys():
        folder_path = os.path.join(base_notebooks_dir, folder_key)
        if os.path.exists(folder_path):
            print(f"   - notebooks/{folder_key}/README.md")

if __name__ == "__main__":
    main()
