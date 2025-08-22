import pandas as pd
import numpy as np
import plotly.io as pio
import plotly.express as px
pio.renderers.default = "notebook+plotly_mimetype"

def analyze_top_performers(df, group_col='store', target_col='sales', top_n=10, width=1200, height=500):
    """
    Analyze top performing entities (stores, days, months, etc.)
    
    Parameters:
    - df: DataFrame 
    - group_col: column to group by ('store', 'day', 'month', etc.)
    - target_col: metric to analyze ('sales' or 'customers')  
    - top_n: number of top performers to show
    """
    
    # Filter out closed stores (e.g., sales = 0) for unbiased and fair comparison
    df = df[df[target_col] > 0].copy()
    
    # Calculate averages and get top performers
    group_avg = df.groupby(group_col)[target_col].mean()
    top_performers = group_avg.nlargest(top_n)
    
    # Visualization
    fig = px.bar(
        x=top_performers.index.astype(str),
        y=top_performers.values,
        title=f'Top {top_n} {group_col.title()} by Average {target_col.title()}',
        labels={'x': group_col.title(), 'y': f'Average {target_col.title()}'}
    )
    fig.update_layout(title_x=0.5, height=height, width=width)
    fig.show(config={'displayModeBar': True, 'displaylogo': False})
    
    # Performance analysis
    print(f"Top {top_n} {group_col.title()} Performance Analysis:")
    print("=" * 55)
    print(f"{'Rank':<4} {group_col.title():<10} {'Average':<15} {'% of #1':<10}")
    print("-" * 55)
    
    for i, (entity, avg_value) in enumerate(top_performers.items(), 1):
        pct_of_top = (avg_value / top_performers.iloc[0]) * 100
        currency = "€" if target_col == 'sales' else ""
        print(f"{i:<4} {str(entity):<10} {currency}{avg_value:>9,.0f}     {pct_of_top:>6.1f}%")
    
    # Summary statistics
    total_entities = len(group_avg)
    top_avg = top_performers.mean()
    overall_avg = group_avg.mean()
    performance_gap = ((top_avg - overall_avg) / overall_avg) * 100
    
    print(f"\nSummary Statistics:")
    print(f"Total {group_col}s analyzed: {total_entities:,}")
    print(f"Top {top_n} average: {currency}{top_avg:,.0f}")
    print(f"Overall average: {currency}{overall_avg:,.0f}")
    print(f"Top {top_n} outperform by: {performance_gap:.1f}%")
    
    return top_performers
