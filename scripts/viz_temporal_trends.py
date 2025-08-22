import pandas as pd
import numpy as np
import plotly.io as pio
import plotly.express as px
pio.renderers.default = "notebook+plotly_mimetype"

def analyze_temporal_trends(df, time_col='month', target_col='sales', width=1200, height=500):
    """
    Analyze trends over time periods (month_name, day_name, year, etc.)
    
    Parameters:
    - df: DataFrame
    - time_col: time dimension ('month_name', 'day_name', 'year', etc.)
    - target_col: metric to analyze ('sales' or 'customers')
    """
    # Filter out closed stores (e.g., sales = 0) for unbiased and fair comparison
    df = df[df[target_col] > 0].copy()

   # Calculate averages by time period
    time_stats = df.groupby(time_col).agg({
        target_col: ['mean', 'std', 'count']
    }).round(0)
    
    time_stats.columns = ['avg', 'std', 'count']
    time_stats = time_stats.reset_index().sort_values('avg', ascending=False)
    
    # Visualization
    fig = px.bar(
        time_stats,
        x=time_col,
        y='avg',
        title=f'{target_col.title()} Performance by {time_col.title()}',
        color='avg',
        color_continuous_scale='viridis'
    )
    fig.update_layout(title_x=0.5, height=height, width=width)
    fig.show(config={'displayModeBar': True, 'displaylogo': False})
    
    # Trend analysis
    print(f"{time_col.title()} Performance Analysis:")
    print("=" * 50)
    print(f"{'Rank':<4} {time_col.title():<12} {'Average':<15} {'Std Dev':<10} {'Count':<8}")
    print("-" * 60)
    
    for i, row in time_stats.iterrows():
        currency = "€" if target_col == 'sales' else ""
        print(f"{i+1:<4} {str(row[time_col]):<12} {currency}{row['avg']:>9,.0f}     {currency}{row['std']:>6,.0f}   {row['count']:>6,.0f}")
    
    # Key insights
    best_period = time_stats.iloc[0][time_col]
    worst_period = time_stats.iloc[-1][time_col]
    best_value = time_stats.iloc[0]['avg']
    worst_value = time_stats.iloc[-1]['avg']
    volatility = ((best_value - worst_value) / time_stats['avg'].mean()) * 100
    
    currency = "€" if target_col == 'sales' else ""
    print(f"\nKey Insights:")
    print(f"Best {time_col}: {best_period} ({currency}{best_value:,.0f})")
    print(f"Worst {time_col}: {worst_period} ({currency}{worst_value:,.0f})")
    print(f"Performance range: {currency}{best_value - worst_value:,.0f}")
    print(f"Volatility: {volatility:.1f}%")
    
    return time_stats
