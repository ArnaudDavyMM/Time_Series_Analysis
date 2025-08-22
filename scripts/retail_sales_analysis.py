# Optimized Retail Sales Analysis
# Performance-enhanced version with matplotlib/seaborn instead of Plotly

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
from scipy import stats
from sklearn.preprocessing import StandardScaler
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.tsa.seasonal import seasonal_decompose
from statsmodels.tsa.stattools import adfuller
from statsmodels.graphics.tsaplots import plot_acf, plot_pacf
import itertools

warnings.filterwarnings('ignore')
plt.style.use('default')
sns.set_palette("husl")

class OptimizedRetailSalesAnalyzer:
    def __init__(self, train_df):
        self.train_df = train_df.copy()
        self.prepare_data()
    
    def prepare_data(self):
        """Prepare and clean the dataset efficiently"""
        # Ensure date column is datetime
        if 'date' not in self.train_df.columns:
            print("Warning: 'date' column not found. Please ensure your dataset has a 'date' column.")
            return
        
        # Optimize memory usage
        self.train_df['date'] = pd.to_datetime(self.train_df['date'])
        
        # Sort by date (more efficient than ascending=True)
        self.train_df.sort_values('date', inplace=True)
        
        # Transform categorical variables efficiently
        if 'stateholiday' in self.train_df.columns:
            self.train_df['stateholiday'] = self.train_df['stateholiday'].replace({
                0: 0, '0': 0, 'a': 1, 'b': 2, 'c': 3
            })
        
        # Add time-based features (vectorized operations)
        self.train_df['day'] = self.train_df['date'].dt.day_name().str[:3]
        self.train_df['week'] = self.train_df['date'].dt.isocalendar().week
        self.train_df['month'] = self.train_df['date'].dt.month_name().str[:3]
        self.train_df['quarter'] = self.train_df['date'].dt.quarter
        self.train_df['year'] = self.train_df['date'].dt.year
        self.train_df['day_of_year'] = self.train_df['date'].dt.dayofyear
        
        print("Data preparation completed successfully!")
    
    def enhanced_summary_statistics(self):
        """Generate comprehensive summary statistics efficiently"""
        print("="*60)
        print("ENHANCED SUMMARY STATISTICS")
        print("="*60)
        
        # Basic info
        print("\n1. DATASET OVERVIEW")
        print("-" * 30)
        print(f"Dataset shape: {self.train_df.shape}")
        print(f"Date range: {self.train_df['date'].min()} to {self.train_df['date'].max()}")
        print(f"Total unique stores: {self.train_df['store'].nunique()}")
        print(f"Total days covered: {self.train_df['date'].nunique()}")
        
        # Missing values analysis (more efficient)
        print("\n2. MISSING VALUES ANALYSIS")
        print("-" * 30)
        missing_info = self.train_df.isnull().sum()
        missing_info = missing_info[missing_info > 0]
        if len(missing_info) > 0:
            missing_percent = (missing_info / len(self.train_df)) * 100
            missing_df = pd.DataFrame({
                'Missing Count': missing_info,
                'Missing Percentage': missing_percent
            })
            print(missing_df.round(2))
        else:
            print("No missing values found!")
        
        print(f"\nDuplicated rows: {self.train_df.duplicated().sum()}")
        
        # Detailed statistics for numerical columns
        print("\n3. DETAILED NUMERICAL STATISTICS")
        print("-" * 30)
        numerical_cols = self.train_df.select_dtypes(include=[np.number]).columns.tolist()
        
        if numerical_cols:
            stats_df = self.train_df[numerical_cols].describe()
            
            # Add additional statistics efficiently
            additional_stats = pd.DataFrame(index=['skewness', 'kurtosis', 'zeros', 'zeros_pct'])
            for col in numerical_cols:
                col_data = self.train_df[col]
                additional_stats.loc['skewness', col] = col_data.skew()
                additional_stats.loc['kurtosis', col] = col_data.kurtosis()
                zeros_count = (col_data == 0).sum()
                additional_stats.loc['zeros', col] = zeros_count
                additional_stats.loc['zeros_pct', col] = (zeros_count / len(col_data)) * 100
            
            stats_df = pd.concat([stats_df, additional_stats])
            print(stats_df.round(3))
        
        # Sales-specific insights
        if 'sales' in self.train_df.columns:
            print("\n4. SALES-SPECIFIC INSIGHTS")
            print("-" * 30)
            sales_data = self.train_df['sales']
            zero_sales = (sales_data == 0).sum()
            zero_pct = (zero_sales / len(sales_data)) * 100
            
            print(f"Sales Distribution Analysis:")
            print(f"- Mean: {sales_data.mean():.2f}")
            print(f"- Median: {sales_data.median():.2f}")
            print(f"- Standard Deviation: {sales_data.std():.2f}")
            skew_val = sales_data.skew()
            print(f"- Skewness: {skew_val:.3f} ({'Right' if skew_val > 0 else 'Left'} skewed)")
            print(f"- Zero sales days: {zero_sales} ({zero_pct:.1f}%)")
            print(f"- Sales range: {sales_data.min():.2f} - {sales_data.max():.2f}")
            print(f"- IQR: {sales_data.quantile(0.75) - sales_data.quantile(0.25):.2f}")
        
        return stats_df if 'stats_df' in locals() else None
    
    def exploratory_data_analysis(self):
        """Comprehensive EDA using matplotlib/seaborn for better performance"""
        print("\n" + "="*60)
        print("EXPLORATORY DATA ANALYSIS")
        print("="*60)
        
        # Create figure with subplots
        fig = plt.figure(figsize=(20, 16))
        
        # 1. Sales Distribution
        if 'sales' in self.train_df.columns:
            plt.subplot(3, 3, 1)
            sales_data = self.train_df[self.train_df['sales'] > 0]['sales']
            plt.hist(sales_data, bins=50, alpha=0.7, color='skyblue', edgecolor='black')
            plt.title('Sales Distribution (Excluding Zeros)')
            plt.xlabel('Sales')
            plt.ylabel('Frequency')
        
        # 2. Sales vs Customers scatter
        if 'sales' in self.train_df.columns and 'customers' in self.train_df.columns:
            plt.subplot(3, 3, 2)
            # Sample data for performance
            sample_size = min(3000, len(self.train_df))
            sample_data = self.train_df.sample(sample_size)
            plt.scatter(sample_data['customers'], sample_data['sales'], alpha=0.5, s=1)
            plt.title('Sales vs Customers')
            plt.xlabel('Customers')
            plt.ylabel('Sales')
        
        # 3. Open vs Closed stores
        if 'open' in self.train_df.columns:
            plt.subplot(3, 3, 3)
            open_counts = self.train_df['open'].value_counts()
            plt.pie(open_counts.values, labels=['Closed', 'Open'], autopct='%1.1f%%')
            plt.title('Store Status Distribution')
        
        # 4. Sales by day of week
        if 'sales' in self.train_df.columns and 'day' in self.train_df.columns:
            plt.subplot(3, 3, 4)
            day_order = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
            daily_sales = self.train_df.groupby('day')['sales'].mean().reindex(day_order)
            daily_sales.plot(kind='bar', color='lightcoral')
            plt.title('Average Sales by Day of Week')
            plt.xlabel('Day')
            plt.ylabel('Average Sales')
            plt.xticks(rotation=45)
        
        # 5. Sales by month
        if 'sales' in self.train_df.columns and 'month' in self.train_df.columns:
            plt.subplot(3, 3, 5)
            month_order = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
            monthly_sales = self.train_df.groupby('month')['sales'].mean().reindex(month_order)
            monthly_sales.plot(kind='bar', color='lightgreen')
            plt.title('Average Sales by Month')
            plt.xlabel('Month')
            plt.ylabel('Average Sales')
            plt.xticks(rotation=45)
        
        # 6. Sales trend over time (sampled for performance)
        if 'sales' in self.train_df.columns and 'date' in self.train_df.columns:
            plt.subplot(3, 3, 6)
            daily_trend = self.train_df.groupby('date')['sales'].sum()
            # Sample every nth point for large datasets
            if len(daily_trend) > 1000:
                step = len(daily_trend) // 500
                daily_trend = daily_trend.iloc[::step]
            plt.plot(daily_trend.index, daily_trend.values, linewidth=1)
            plt.title('Sales Trend Over Time')
            plt.xlabel('Date')
            plt.ylabel('Total Sales')
            plt.xticks(rotation=45)
        
        # 7-9. Holiday and promotion impacts
        subplot_positions = [7, 8, 9]
        categorical_cols = ['schoolholiday', 'stateholiday', 'promo']
        colors = ['orange', 'purple', 'brown']
        
        for i, col in enumerate(categorical_cols):
            if col in self.train_df.columns and 'sales' in self.train_df.columns:
                plt.subplot(3, 3, subplot_positions[i])
                impact_data = self.train_df.groupby(col)['sales'].mean()
                impact_data.plot(kind='bar', color=colors[i])
                plt.title(f'{col.title()} Impact on Sales')
                plt.xlabel(col.title())
                plt.ylabel('Average Sales')
                plt.xticks(rotation=0)
        
        plt.tight_layout()
        plt.show()
        
        # Correlation heatmap
        self.plot_correlation_heatmap()
        
        # Store performance analysis
        self.analyze_store_performance()
    
    def plot_correlation_heatmap(self):
        """Create correlation heatmap efficiently"""
        numerical_cols = self.train_df.select_dtypes(include=[np.number]).columns.tolist()
        
        if len(numerical_cols) > 1:
            plt.figure(figsize=(12, 10))
            correlation_matrix = self.train_df[numerical_cols].corr()
            
            # Create mask for upper triangle
            mask = np.triu(np.ones_like(correlation_matrix, dtype=bool))
            
            sns.heatmap(correlation_matrix, mask=mask, annot=True, cmap='coolwarm', 
                       center=0, square=True, fmt='.2f', cbar_kws={"shrink": .8})
            plt.title('Correlation Heatmap of Numerical Variables', fontsize=16)
            plt.tight_layout()
            plt.show()
    
    def analyze_store_performance(self):
        """Analyze store performance efficiently"""
        if 'store' not in self.train_df.columns or 'sales' not in self.train_df.columns:
            print("Store or sales data not available for analysis.")
            return
        
        # Efficient aggregation
        agg_dict = {
            'sales': ['mean', 'sum', 'std', 'count']
        }
        if 'customers' in self.train_df.columns:
            agg_dict['customers'] = 'mean'
        
        store_stats = self.train_df.groupby('store').agg(agg_dict)
        
        # Flatten column names
        store_stats.columns = ['avg_sales', 'total_sales', 'sales_std', 'days_open'] + \
                             (['avg_customers'] if 'customers' in agg_dict else [])
        
        store_stats['cv'] = store_stats['sales_std'] / store_stats['avg_sales']
        store_stats = store_stats.round(2)
        
        # Display top and bottom performers
        print("\nTOP 10 PERFORMING STORES (by average sales):")
        top_cols = ['avg_sales', 'total_sales', 'days_open']
        print(store_stats.nlargest(10, 'avg_sales')[top_cols])
        
        print("\nBOTTOM 10 PERFORMING STORES (by average sales):")
        print(store_stats.nsmallest(10, 'avg_sales')[top_cols])
        
        # Visualizations
        fig, axes = plt.subplots(2, 2, figsize=(15, 10))
        
        # Average sales distribution
        axes[0, 0].hist(store_stats['avg_sales'], bins=30, alpha=0.7, color='skyblue', edgecolor='black')
        axes[0, 0].set_title('Distribution of Average Sales Across Stores')
        axes[0, 0].set_xlabel('Average Sales')
        axes[0, 0].set_ylabel('Number of Stores')
        
        # Sales variability
        axes[0, 1].scatter(store_stats['avg_sales'], store_stats['cv'], alpha=0.6, s=20)
        axes[0, 1].set_title('Sales Variability vs Average Sales')
        axes[0, 1].set_xlabel('Average Sales')
        axes[0, 1].set_ylabel('Coefficient of Variation')
        
        # Top 20 stores performance
        top_20_stores = store_stats.nlargest(20, 'avg_sales')
        axes[1, 0].bar(range(len(top_20_stores)), top_20_stores['avg_sales'], color='coral')
        axes[1, 0].set_title('Top 20 Stores by Average Sales')
        axes[1, 0].set_xlabel('Store Rank')
        axes[1, 0].set_ylabel('Average Sales')
        
        # Sales vs customers (if available)
        if 'avg_customers' in store_stats.columns:
            axes[1, 1].scatter(store_stats['avg_customers'], store_stats['avg_sales'], alpha=0.6, s=20)
            axes[1, 1].set_title('Average Sales vs Average Customers')
            axes[1, 1].set_xlabel('Average Customers')
            axes[1, 1].set_ylabel('Average Sales')
        else:
            axes[1, 1].text(0.5, 0.5, 'Customer data\nnot available', 
                           ha='center', va='center', transform=axes[1, 1].transAxes)
            axes[1, 1].set_title('Customer Analysis')
        
        plt.tight_layout()
        plt.show()
    
    def time_series_analysis(self):
        """Optimized time series analysis"""
        print("\n" + "="*60)
        print("TIME SERIES ANALYSIS & MODELING")
        print("="*60)
        
        if 'sales' not in self.train_df.columns or 'open' not in self.train_df.columns:
            print("Required columns 'sales' and 'open' not found.")
            return
        
        # Create efficient subset
        mask = (self.train_df['sales'] > 0) & (self.train_df['open'] > 0)
        train_sales = self.train_df[mask].copy()
        
        if len(train_sales) == 0:
            print("No data available for time series analysis.")
            return
        
        train_sales.set_index('date', inplace=True)
        print(f"Time series data shape: {train_sales.shape}")
        
        # Log transform for better stationarity
        train_sales['log_sales'] = np.log(train_sales['sales'])
        
        # Create time series at different frequencies
        ts_daily = train_sales['log_sales'].resample('D').mean().dropna()
        ts_weekly = train_sales['log_sales'].resample('W').mean().dropna()
        ts_monthly = train_sales['log_sales'].resample('M').mean().dropna()
        
        # Plot time series efficiently
        fig, axes = plt.subplots(3, 1, figsize=(15, 12))
        
        # Daily series (last 365 days for performance)
        daily_plot_data = ts_daily.tail(365) if len(ts_daily) > 365 else ts_daily
        axes[0].plot(daily_plot_data.index, daily_plot_data.values, linewidth=1)
        axes[0].set_title('Daily Log Sales (Recent Period)')
        axes[0].set_ylabel('Log Sales')
        
        # Weekly series
        axes[1].plot(ts_weekly.index, ts_weekly.values, color='orange', linewidth=1.5)
        axes[1].set_title('Weekly Average Log Sales')
        axes[1].set_ylabel('Log Sales')
        
        # Monthly series
        axes[2].plot(ts_monthly.index, ts_monthly.values, color='green', linewidth=2)
        axes[2].set_title('Monthly Average Log Sales')
        axes[2].set_ylabel('Log Sales')
        axes[2].set_xlabel('Date')
        
        plt.tight_layout()
        plt.show()
        
        # Further analysis on weekly data
        if len(ts_weekly) >= 24:  # Need minimum data for analysis
            self.analyze_time_series_components(ts_weekly)
        else:
            print("Insufficient data for detailed time series analysis.")
    
    def analyze_time_series_components(self, ts):
        """Analyze time series components efficiently"""
        try:
            # Seasonal decomposition (if enough data)
            if len(ts) >= 52:  # At least one year of weekly data
                decomposition = seasonal_decompose(ts, model='additive', period=52)
                
                fig, axes = plt.subplots(4, 1, figsize=(15, 12))
                
                decomposition.observed.plot(ax=axes[0], title='Original Time Series')
                decomposition.trend.plot(ax=axes[1], title='Trend Component')
                decomposition.seasonal.plot(ax=axes[2], title='Seasonal Component')
                decomposition.resid.plot(ax=axes[3], title='Residual Component')
                
                plt.tight_layout()
                plt.show()
            
            # Stationarity test
            self.test_stationarity(ts)
            
            # ACF and PACF plots
            if len(ts) >= 50:  # Minimum for meaningful ACF/PACF
                fig, axes = plt.subplots(2, 1, figsize=(15, 8))
                
                plot_acf(ts, ax=axes[0], lags=min(40, len(ts)//4), title='Autocorrelation Function')
                plot_pacf(ts, ax=axes[1], lags=min(40, len(ts)//4), title='Partial Autocorrelation Function')
                
                plt.tight_layout()
                plt.show()
            
        except Exception as e:
            print(f"Error in time series component analysis: {e}")
    
    def test_stationarity(self, ts):
        """Test for stationarity efficiently"""
        print("\nSTATIONARITY TEST")
        print("-" * 30)
        
        try:
            result = adfuller(ts.dropna())
            
            print("Augmented Dickey-Fuller Test Results:")
            print(f"ADF Statistic: {result[0]:.6f}")
            print(f"p-value: {result[1]:.6f}")
            print("Critical Values:")
            for key, value in result[4].items():
                print(f"  {key}: {value:.3f}")
            
            is_stationary = result[1] <= 0.05
            print(f"\nResult: Series is {'stationary' if is_stationary else 'non-stationary'}")
            
            if not is_stationary and len(ts) > 2:
                # Test first difference
                ts_diff = ts.diff().dropna()
                if len(ts_diff) > 0:
                    result_diff = adfuller(ts_diff)
                    print(f"\nFirst Difference Test:")
                    print(f"ADF Statistic: {result_diff[0]:.6f}")
                    print(f"p-value: {result_diff[1]:.6f}")
                    is_diff_stationary = result_diff[1] <= 0.05
                    print(f"Result: First differenced series is {'stationary' if is_diff_stationary else 'non-stationary'}")
        
        except Exception as e:
            print(f"Error in stationarity test: {e}")
    
    def simple_arima_analysis(self, ts):
        """Simplified ARIMA analysis for better performance"""
        print("\nSIMPLE ARIMA ANALYSIS")
        print("-" * 30)
        
        if len(ts) < 50:
            print("Insufficient data for ARIMA modeling.")
            return
        
        try:
            # Try a few simple ARIMA configurations
            configs = [(1,1,1), (0,1,1), (1,1,0), (2,1,2)]
            best_aic = np.inf
            best_model = None
            best_config = None
            
            for config in configs:
                try:
                    model = ARIMA(ts, order=config)
                    fitted = model.fit()
                    
                    if fitted.aic < best_aic:
                        best_aic = fitted.aic
                        best_model = fitted
                        best_config = config
                        
                except:
                    continue
            
            if best_model is not None:
                print(f"Best ARIMA configuration: {best_config}")
                print(f"AIC: {best_aic:.2f}")
                
                # Plot residuals
                residuals = best_model.resid
                
                fig, axes = plt.subplots(2, 2, figsize=(12, 8))
                
                # Residuals plot
                axes[0, 0].plot(residuals)
                axes[0, 0].set_title('Residuals')
                
                # Residuals histogram
                axes[0, 1].hist(residuals, bins=20, alpha=0.7)
                axes[0, 1].set_title('Residuals Distribution')
                
                # Q-Q plot
                stats.probplot(residuals, dist="norm", plot=axes[1, 0])
                axes[1, 0].set_title('Q-Q Plot of Residuals')
                
                # Residuals vs fitted
                fitted_values = best_model.fittedvalues
                axes[1, 1].scatter(fitted_values, residuals, alpha=0.6)
                axes[1, 1].set_title('Residuals vs Fitted')
                axes[1, 1].set_xlabel('Fitted Values')
                axes[1, 1].set_ylabel('Residuals')
                
                plt.tight_layout()
                plt.show()
            else:
                print("No suitable ARIMA model found.")
                
        except Exception as e:
            print(f"Error in ARIMA analysis: {e}")
    
    def generate_insights(self):
        """Generate actionable business insights"""
        print("\n" + "="*60)
        print("BUSINESS INSIGHTS & RECOMMENDATIONS")
        print("="*60)
        
        insights = []
        recommendations = []
        
        # Sales analysis
        if 'sales' in self.train_df.columns:
            sales_data = self.train_df['sales']
            zero_sales_pct = (sales_data == 0).mean() * 100
            
            if zero_sales_pct > 10:
                insights.append(f"• {zero_sales_pct:.1f}% of records show zero sales")
                recommendations.append("• Investigate reasons for store closures and data quality")
            
            if sales_data.skew() > 1:
                insights.append("• Sales distribution is highly right-skewed")
                recommendations.append("• Consider log transformation for predictive modeling")
        
        # Temporal patterns
        if all(col in self.train_df.columns for col in ['day', 'sales']):
            daily_sales = self.train_df[self.train_df['sales'] > 0].groupby('day')['sales'].mean()
            if len(daily_sales) > 1:
                best_day = daily_sales.idxmax()
                worst_day = daily_sales.idxmin()
                pct_diff = ((daily_sales.max() - daily_sales.min()) / daily_sales.min()) * 100
                
                insights.append(f"• {best_day} shows highest sales, {worst_day} shows lowest ({pct_diff:.1f}% difference)")
                recommendations.append("• Optimize staffing and inventory based on daily patterns")
        
        # Store performance variability
        if all(col in self.train_df.columns for col in ['store', 'sales']):
            store_cv = self.train_df.groupby('store')['sales'].agg(['mean', 'std'])
            store_cv['cv'] = store_cv['std'] / store_cv['mean']
            high_var_stores = (store_cv['cv'] > 1).sum()
            total_stores = len(store_cv)
            
            if high_var_stores / total_stores > 0.2:
                insights.append(f"• {high_var_stores}/{total_stores} stores show high sales variability")
                recommendations.append("• Investigate operational consistency across high-variability stores")
        
        # Holiday impacts
        for holiday_type in ['schoolholiday', 'stateholiday']:
            if all(col in self.train_df.columns for col in [holiday_type, 'sales']):
                holiday_impact = self.train_df.groupby(holiday_type)['sales'].mean()
                if len(holiday_impact) > 1:
                    pct_change = ((holiday_impact.iloc[-1] - holiday_impact.iloc[0]) / holiday_impact.iloc[0]) * 100
                    if abs(pct_change) > 5:
                        direction = "increases" if pct_change > 0 else "decreases"
                        insights.append(f"• {holiday_type.title()} {direction} sales by {abs(pct_change):.1f}%")
                        recommendations.append(f"• Adjust {holiday_type} inventory and promotion strategies")
        
        # Print results
        if insights:
            print("\nKEY INSIGHTS:")
            for insight in insights:
                print(insight)
        
        if recommendations:
            print("\nRECOMMENDATIONS:")
            for rec in recommendations:
                print(rec)
        
        # General recommendations
        print("\nGENERAL RECOMMENDATIONS:")
        print("• Implement demand forecasting based on historical patterns")
        print("• Monitor store performance metrics regularly")
        print("• Consider external factors (weather, events, competition)")
        print("• Use A/B testing for promotional strategies")
        print("• Develop store-specific optimization strategies")
    
    def run_complete_analysis(self):
        """Run the complete optimized analysis pipeline"""
        print("Starting Optimized Retail Sales Analysis...")
        print("="*60)
        
        try:
            # 1. Enhanced Summary Statistics
            print("Phase 1: Statistical Summary...")
            self.enhanced_summary_statistics()
            
            # 2. Exploratory Data Analysis
            print("\nPhase 2: Exploratory Analysis...")
            self.exploratory_data_analysis()
            
            # 3. Time Series Analysis
            print("\nPhase 3: Time Series Analysis...")
            self.time_series_analysis()
            
            # 4. Generate Insights
            print("\nPhase 4: Generating Insights...")
            self.generate_insights()
            
            print("\n" + "="*60)
            print("ANALYSIS COMPLETED SUCCESSFULLY!")
            print("="*60)
            
        except Exception as e:
            print(f"Error during analysis: {e}")
            print("Please check your data format and try again.")

# Example usage:
# analyzer = OptimizedRetailSalesAnalyzer(train_df)
# analyzer.run_complete_analysis()

# Or run individual components:
# analyzer.enhanced_summary_statistics()
# analyzer.exploratory_data_analysis()
# analyzer.time_series_analysis()
