#!/bin/bash

# Environment Setup Script for Time Series Analysis Project
# Creates .env file, directories, and validates configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${2:-$NC}$1${NC}"; }

show_header() {
    echo ""
    log "╔══════════════════════════════════════════════════════════════════════════════╗" $BLUE
    log "║                    Time Series Analysis - Environment Setup                  ║" $BLUE  
    log "║                                                                              ║" $BLUE
    log "║  This script will help you set up your project environment                  ║" $GREEN
    log "╚══════════════════════════════════════════════════════════════════════════════╝" $BLUE
    echo ""
}

create_env_file() {
    local env_file=".env"
    local template_file=".env.template"
    
    if [ -f "$env_file" ]; then
        log "⚠️  .env file already exists" $YELLOW
        read -p "Do you want to backup and recreate it? (y/n): " recreate
        if [[ "$recreate" == "y" ]]; then
            cp "$env_file" "${env_file}.backup.$(date +%Y%m%d_%H%M%S)"
            log "✅ Backup created" $GREEN
        else
            log "ℹ️  Keeping existing .env file" $BLUE
            return 0
        fi
    fi
    
    log "📝 Creating .env file..." $BLUE
    
    # Get project root
    local project_root=$(pwd)
    read -p "📁 Project root directory [$project_root]: " user_root
    project_root="${user_root:-$project_root}"
    
    # Get GitHub token
    local github_token=""
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        github_token="$GITHUB_TOKEN"
        log "✅ Using existing GITHUB_TOKEN" $GREEN
    else
        read -p "🔑 Enter your GitHub Personal Access Token (or press Enter to skip): " github_token
    fi
    
    # Get basic info
    read -p "👤 GitHub username [ArnaudDavyMM]: " github_user
    github_user="${github_user:-ArnaudDavyMM}"
    
    read -p "📦 Repository name [Time_Series_Analysis]: " repo_name
    repo_name="${repo_name:-Time_Series_Analysis}"
    
    # Environment type
    echo ""
    echo "🔧 Environment type:"
    echo "1. Development (local work)"
    echo "2. Staging (testing)"
    echo "3. Production (live)"
    read -p "Choose (1-3) [1]: " env_type_choice
    
    case "${env_type_choice:-1}" in
        1) environment="development" ;;
        2) environment="staging" ;;
        3) environment="production" ;;
        *) environment="development" ;;
    esac
    
    # Create the .env file
    cat > "$env_file" << EOF
# =============================================================================
# Time Series Analysis Project - Environment Configuration
# Generated on $(date)
# =============================================================================

# =============================================================================
# GitHub & Repository Settings
# =============================================================================
GITHUB_TOKEN=$github_token
GITHUB_USERNAME=$github_user
REPO_NAME=$repo_name
REPO_URL=https://github.com/$github_user/$repo_name.git

# =============================================================================
# Project Structure
# =============================================================================
PROJECT_ROOT=$project_root
DATA_DIR=\${PROJECT_ROOT}/data
RAW_DATA_DIR=\${DATA_DIR}/raw
PROCESSED_DATA_DIR=\${DATA_DIR}/processed
EXTERNAL_DATA_DIR=\${DATA_DIR}/external
OUTPUT_DIR=\${PROJECT_ROOT}/output
MODELS_DIR=\${OUTPUT_DIR}/models
FIGURES_DIR=\${OUTPUT_DIR}/figures
REPORTS_DIR=\${OUTPUT_DIR}/reports

# =============================================================================
# Development Settings
# =============================================================================
ENVIRONMENT=$environment
DEBUG=True
VERBOSE=True
LOG_LEVEL=INFO
LOG_FILE=\${PROJECT_ROOT}/logs/app.log

# =============================================================================
# Machine Learning Settings
# =============================================================================
MODEL_RANDOM_STATE=42
N_JOBS=-1
CROSS_VALIDATION_FOLDS=5

# =============================================================================
# Data Sources & APIs (Add your keys here)
# =============================================================================
# ALPHA_VANTAGE_API_KEY=your_alpha_vantage_key_here
# QUANDL_API_KEY=your_quandl_key_here
# FRED_API_KEY=your_fred_key_here
# YAHOO_FINANCE_API_KEY=your_yahoo_finance_key_here
# OPENWEATHER_API_KEY=your_openweather_key_here

# =============================================================================
# Database Configuration (Optional)
# =============================================================================
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=timeseries_analysis
# DB_USER=your_db_username
# DB_PASSWORD=your_db_password
# SQLITE_DB_PATH=\${DATA_DIR}/timeseries.db

# =============================================================================
# Cloud Storage (Optional)
# =============================================================================
# AWS_ACCESS_KEY_ID=your_aws_access_key
# AWS_SECRET_ACCESS_KEY=your_aws_secret_key
# AWS_REGION=us-east-1
# AWS_S3_BUCKET=your-timeseries-bucket

# =============================================================================
# Performance Settings
# =============================================================================
MAX_MEMORY_GB=8
CHUNK_SIZE=10000
MAX_WORKERS=4

# =============================================================================
# Visualization Settings
# =============================================================================
FIGURE_DPI=300
FIGURE_FORMAT=png
PLOT_STYLE=seaborn-v0_8
COLOR_PALETTE=viridis
EOF
    
    log "✅ .env file created successfully" $GREEN
}

create_directories() {
    log "📁 Creating project directories..." $BLUE
    
    # Load PROJECT_ROOT from .env if it exists
    local project_root=$(pwd)
    if [ -f .env ]; then
        source .env 2>/dev/null || true
        project_root="${PROJECT_ROOT:-$(pwd)}"
    fi
    
    # Core directories
    local dirs=(
        "data/raw"
        "data/processed" 
        "data/external"
        "output/models"
        "output/figures"
        "output/reports"
        "logs"
        "notebooks/exploratory"
        "notebooks/analysis"
        "notebooks/modeling"
        "src/data"
        "src/features"
        "src/models"
        "src/visualization"
        "scripts/data_collection"
        "scripts/preprocessing"
        "scripts/modeling"
        "tests/unit"
        "tests/integration"
        "docs"
        "configs"
        "credentials"
    )
    
    local created_count=0
    for dir in "${dirs[@]}"; do
        if [ ! -d "$project_root/$dir" ]; then
            mkdir -p "$project_root/$dir"
            created_count=$((created_count + 1))
        fi
    done
    
    log "✅ Created $created_count new directories" $GREEN
}

create_gitignore() {
    if [ -f .gitignore ]; then
        log "ℹ️  .gitignore already exists" $BLUE
        return 0
    fi
    
    log "📝 Creating .gitignore..." $BLUE
    
    cat > .gitignore << 'EOF'
# Environment and secrets
.env
.env.*
!.env.template
credentials/
*.key
*.pem
*secret*
*password*

# Data files
data/raw/
data/processed/
data/external/
*.csv
*.parquet
*.h5
*.hdf5
*.pkl
*.pickle

# Model artifacts
output/models/
*.model
*.joblib
mlruns/
wandb/

# Logs
logs/
*.log

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

# Virtual environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

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

# Temporary files
*.tmp
.tmp/
temp/

# Archives
*.tar.gz
*.zip
*.rar
EOF
    
    log "✅ .gitignore created" $GREEN
}

create_readme_files() {
    log "📝 Creating README files..." $BLUE
    
    # Main README if it doesn't exist
    if [ ! -f README.md ]; then
        cat > README.md << 'EOF'
# Time Series Analysis Project

A comprehensive time series analysis project with data collection, preprocessing, modeling, and visualization capabilities.

## Project Structure

```
├── data/                   # Data storage
│   ├── raw/               # Original, immutable data
│   ├── processed/         # Cleaned and processed data
│   └── external/          # External data sources
├── src/                   # Source code
│   ├── data/              # Data collection and preprocessing
│   ├── features/          # Feature engineering
│   ├── models/            # Machine learning models
│   └── visualization/     # Plotting and visualization
├── notebooks/             # Jupyter notebooks
│   ├── exploratory/       # Exploratory data analysis
│   ├── analysis/          # Analysis notebooks
│   └── modeling/          # Model development
├── scripts/               # Utility scripts
├── output/                # Generated outputs
│   ├── models/            # Trained models
│   ├── figures/           # Generated plots
│   └── reports/           # Analysis reports
├── tests/                 # Test files
├── docs/                  # Documentation
└── configs/               # Configuration files
```

## Getting Started

1. Clone this repository
2. Set up your environment: `bash setup_env.sh`
3. Install dependencies: `pip install -r requirements.txt`
4. Configure your API keys in `.env`
5. Start with the notebooks in `notebooks/exploratory/`

## Environment Setup

This project uses environment variables for configuration. Run the setup script to create your `.env` file:

```bash
bash setup_env.sh
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests
4. Submit a pull request

## License

This project is licensed under the MIT License.
EOF
        log "✅ Main README.md created" $GREEN
    fi
    
    # Data directory READMEs
    if [ ! -f data/README.md ]; then
        mkdir -p data
        cat > data/README.md << 'EOF'
# Data Directory

This directory contains all data files for the time series analysis project.

## Structure

- `raw/` - Original, immutable data dump
- `processed/` - Cleaned and transformed data
- `external/` - Data from external sources

## Guidelines

1. Never modify files in `raw/` - they should be immutable
2. All processed data should be reproducible from `raw/` data
3. Document data sources and transformations
4. Use consistent naming conventions
5. Include data dictionaries for complex datasets

## Data Sources

Document your data sources here:
- Financial data: Yahoo Finance, Alpha Vantage
- Economic indicators: FRED, World Bank
- Weather data: OpenWeather, NOAA
EOF
        log "✅ data/README.md created" $GREEN
    fi
}

validate_environment() {
    log "🔍 Validating environment..." $BLUE
    
    local errors=0
    
    # Check Python
    if ! command -v python3 >/dev/null; then
        log "❌ Python 3 not found" $RED
        errors=$((errors + 1))
    else
        log "✅ Python 3 found" $GREEN
    fi
    
    # Check pip
    if ! command -v pip >/dev/null; then
        log "❌ pip not found" $RED
        errors=$((errors + 1))
    else
        log "✅ pip found" $GREEN
    fi
    
    # Check git
    if ! command -v git >/dev/null; then
        log "❌ Git not found" $RED
        errors=$((errors + 1))
    else
        log "✅ Git found" $GREEN
    fi
    
    # Check if we're in a git repository
    if [ -d .git ]; then
        log "✅ Git repository detected" $GREEN
    else
        log "⚠️  Not in a Git repository" $YELLOW
        read -p "Initialize Git repository? (y/n): " init_git
        if [[ "$init_git" == "y" ]]; then
            git init
            log "✅ Git repository initialized" $GREEN
        fi
    fi
    
    # Check .env file
    if [ -f .env ]; then
        log "✅ .env file exists" $GREEN
        
        # Validate GitHub token
        if grep -q "GITHUB_TOKEN=your_github_token_here" .env; then
            log "⚠️  GitHub token not configured in .env" $YELLOW
        elif grep -q "GITHUB_TOKEN=" .env && [ -n "$(grep GITHUB_TOKEN .env | cut -d= -f2)" ]; then
            log "✅ GitHub token configured" $GREEN
        else
            log "⚠️  GitHub token missing from .env" $YELLOW
        fi
    else
        log "❌ .env file missing" $RED
        errors=$((errors + 1))
    fi
    
    # Check project structure
    local required_dirs=("data" "src" "notebooks" "output" "logs")
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log "✅ Directory $dir/ exists" $GREEN
        else
            log "⚠️  Directory $dir/ missing" $YELLOW
        fi
    done
    
    if [ $errors -eq 0 ]; then
        log "🎉 Environment validation passed!" $GREEN
    else
        log "⚠️  Found $errors critical issues" $YELLOW
    fi
    
    return $errors
}

install_requirements() {
    log "📦 Setting up Python requirements..." $BLUE
    
    if [ ! -f requirements.txt ]; then
        log "📝 Creating requirements.txt..." $BLUE
        cat > requirements.txt << 'EOF'
# Core data science packages
pandas>=2.0.0
numpy>=1.24.0
scipy>=1.10.0
scikit-learn>=1.3.0

# Time series specific
statsmodels>=0.14.0
arch>=5.3.0
pmdarima>=2.0.0

# Visualization
matplotlib>=3.7.0
seaborn>=0.12.0
plotly>=5.15.0

# Data collection
yfinance>=0.2.0
pandas-datareader>=0.10.0
quandl>=3.7.0
alpha-vantage>=2.3.0

# Machine learning
xgboost>=1.7.0
lightgbm>=4.0.0
catboost>=1.2.0

# Deep learning (optional)
tensorflow>=2.13.0
torch>=2.0.0

# Utilities
python-dotenv>=1.0.0
tqdm>=4.65.0
joblib>=1.3.0
requests>=2.31.0

# Jupyter and development
jupyter>=1.0.0
ipykernel>=6.23.0
black>=23.0.0
flake8>=6.0.0
pytest>=7.4.0

# Database (optional)
sqlalchemy>=2.0.0
psycopg2-binary>=2.9.0

# Cloud and MLOps (optional)
boto3>=1.26.0
mlflow>=2.5.0
wandb>=0.15.0
EOF
        log "✅ requirements.txt created" $GREEN
    fi
    
    # Check if virtual environment exists
    if [ ! -d "venv" ] && [ ! -d ".venv" ]; then
        log "🐍 Creating virtual environment..." $BLUE
        python3 -m venv venv
        log "✅ Virtual environment created" $GREEN
        log "💡 Activate with: source venv/bin/activate" $YELLOW
    else
        log "✅ Virtual environment already exists" $GREEN
    fi
    
    # Ask if user wants to install requirements
    read -p "Install Python requirements now? (y/n): " install_reqs
    if [[ "$install_reqs" == "y" ]]; then
        if [ -d "venv" ]; then
            source venv/bin/activate
        elif [ -d ".venv" ]; then
            source .venv/bin/activate
        fi
        
        log "📦 Installing requirements..." $BLUE
        pip install --upgrade pip
        pip install -r requirements.txt
        log "✅ Requirements installed" $GREEN
    fi
}

create_config_files() {
    log "📝 Creating configuration files..." $BLUE
    
    # Create template_config.yml
    if [ ! -f template_config.yml ]; then
        cat > template_config.yml << 'EOF'
# Template Configuration for Time Series Analysis
# Copy to config.yml and customize for your needs

# Data Collection Settings
data_collection:
  sources:
    yahoo_finance:
      enabled: true
      default_period: "5y"
      default_interval: "1d"
    
    alpha_vantage:
      enabled: false
      function: "TIME_SERIES_DAILY"
      outputsize: "full"
    
    fred:
      enabled: false
      frequency: "daily"
  
  symbols:
    - "AAPL"
    - "GOOGL"
    - "MSFT"
    - "TSLA"
  
  indicators:
    - "GDP"
    - "UNRATE"
    - "CPIAUCSL"

# Preprocessing Settings
preprocessing:
  handle_missing:
    method: "forward_fill"  # forward_fill, backward_fill, interpolate, drop
    max_consecutive: 5
  
  outlier_detection:
    method: "iqr"  # iqr, zscore, isolation_forest
    threshold: 3.0
  
  scaling:
    method: "standard"  # standard, minmax, robust, none
  
  resampling:
    frequency: "D"  # D, W, M, Q, Y
    aggregation: "mean"  # mean, sum, last, first

# Feature Engineering
features:
  technical_indicators:
    - "SMA_20"
    - "SMA_50"
    - "EMA_12"
    - "EMA_26"
    - "RSI_14"
    - "MACD"
    - "Bollinger_Bands"
  
  lag_features:
    lags: [1, 2, 3, 5, 7, 14, 30]
  
  rolling_features:
    windows: [7, 14, 30]
    functions: ["mean", "std", "min", "max"]

# Model Settings
models:
  train_test_split: 0.8
  validation_split: 0.2
  
  arima:
    max_p: 5
    max_d: 2
    max_q: 5
    seasonal: true
  
  lstm:
    sequence_length: 60
    hidden_units: [50, 50]
    dropout: 0.2
    epochs: 100
    batch_size: 32
  
  xgboost:
    n_estimators: 100
    max_depth: 6
    learning_rate: 0.1
    subsample: 0.8
    colsample_bytree: 0.8

# Evaluation Settings
evaluation:
  metrics:
    - "MAE"
    - "MSE"
    - "RMSE"
    - "MAPE"
    - "R2"
  
  cross_validation:
    method: "time_series_split"
    n_splits: 5
  
  backtesting:
    start_date: "2020-01-01"
    end_date: "2023-12-31"
    refit_frequency: "monthly"

# Visualization Settings
visualization:
  style: "seaborn-v0_8"
  figure_size: [12, 8]
  dpi: 300
  color_palette: "viridis"
  
  plots:
    time_series:
      show_trend: true
      show_seasonal: true
      show_residual: true
    
    forecasts:
      confidence_intervals: [0.68, 0.95]
      show_actuals: true
    
    diagnostics:
      residual_plots: true
      qq_plots: true
      acf_pacf_plots: true

# Logging Settings
logging:
  level: "INFO"
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
  file: "logs/timeseries_analysis.log"
  max_size_mb: 10
  backup_count: 5
EOF
        log "✅ template_config.yml created" $GREEN
    fi
    
    # Create logging configuration
    if [ ! -f configs/logging.yml ]; then
        mkdir -p configs
        cat > configs/logging.yml << 'EOF'
version: 1
disable_existing_loggers: False

formatters:
  standard:
    format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
  detailed:
    format: "%(asctime)s - %(name)s - %(levelname)s - %(module)s - %(funcName)s - %(message)s"

handlers:
  console:
    class: logging.StreamHandler
    level: INFO
    formatter: standard
    stream: ext://sys.stdout

  file:
    class: logging.handlers.RotatingFileHandler
    level: DEBUG
    formatter: detailed
    filename: logs/app.log
    maxBytes: 10485760  # 10MB
    backupCount: 5

loggers:
  timeseries_analysis:
    level: DEBUG
    handlers: [console, file]
    propagate: False

root:
  level: INFO
  handlers: [console, file]
EOF
        log "✅ configs/logging.yml created" $GREEN
    fi
}

show_next_steps() {
    log "🎯 Setup complete! Next steps:" $GREEN
    echo ""
    echo "1. 🔧 Activate your virtual environment:"
    echo "   source venv/bin/activate"
    echo ""
    echo "2. 🔑 Configure your API keys in .env:"
    echo "   - GitHub token for automation"
    echo "   - Data source API keys (Alpha Vantage, FRED, etc.)"
    echo ""
    echo "3. 📦 Install requirements (if not done already):"
    echo "   pip install -r requirements.txt"
    echo ""
    echo "4. 🚀 Start your analysis:"
    echo "   jupyter notebook notebooks/"
    echo ""
    echo "5. 🔄 Update your repository script:"
    echo "   chmod +x replace.sh"
    echo "   ./replace.sh"
    echo ""
    log "📚 Documentation:" $BLUE
    echo "   - Main README: README.md"
    echo "   - Data guidelines: data/README.md"
    echo "   - Configuration: template_config.yml"
    echo ""
    log "🔐 Security reminders:" $YELLOW
    echo "   - Never commit .env files"
    echo "   - Keep API keys secure"
    echo "   - Use .gitignore properly"
    echo ""
}

# Main execution
main() {
    show_header
    
    # Run setup steps
    create_env_file
    create_directories
    create_gitignore
    create_readme_files
    create_config_files
    install_requirements
    
    # Validate everything
    echo ""
    validate_environment
    
    # Show next steps
    echo ""
    show_next_steps
    
    log "✨ Environment setup complete!" $GREEN
}

# Run main function
main "$@"
