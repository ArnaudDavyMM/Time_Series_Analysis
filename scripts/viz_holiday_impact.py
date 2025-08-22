import pandas as pd
import numpy as np
import plotly.io as pio
import plotly.express as px
pio.renderers.default = "notebook+plotly_mimetype"

def analyze_stateholiday_impact(df, target_col ='sales', category_col ='day', width =1200, height =500):
    """
    Analyze the impact of state holidays across a specified category (e.g., day, month, store).
    
    Parameters:
    - df: DataFrame with 'stateholiday' column already mapped to labels
    - target_col: metric to analyze ('sales' or 'customers')
    - category_col: grouping category ('day', 'month', 'store', etc.)
    """
    # Filter out closed stores (e.g., sales = 0) for unbiased and fair comparison
    df_open = df[df[target_col] > 0].copy()
    
    # Create summary data
    summary = df_open.groupby([category_col, 'stateholiday'])[target_col].mean().reset_index()
    
    # Visualization
    fig = px.bar(
        summary,
        x =category_col,
        y =target_col,
        color ='stateholiday',
        title =f'State Holiday Impact: {target_col.title()} by {category_col.title()}',
        barmode ='group'
    )
    fig.update_layout(title_x =0.5, height =height, width =width)
    fig.show(config={'displayModeBar': True, 'displaylogo': False})
    
    # Impact analysis
    print(f"State Holiday Impact Analysis - {target_col.title()} by {category_col.title()}:")
    print("=" * 70)
    
    # Get regular day baseline
    regular_avg = df_open[df_open['stateholiday'] == 'Normal Day'][target_col].mean()
    
    # Overall holiday impact
    print("Overall Holiday Impact:")
    print("-" * 25)
    for holiday_label in ['Public', 'Easter', 'Christmas']:
        if holiday_label in df['stateholiday'].values:
            holiday_avg = df_open[df_open['stateholiday'] == holiday_label][target_col].mean()
            if not pd.isna(holiday_avg):
                impact = ((holiday_avg - regular_avg) / regular_avg) * 100
                currency = "€" if target_col == 'sales' else ""
                print(f"{holiday_label:15}: {currency}{holiday_avg:6,.0f} ({impact:+5.1f}% vs regular)")
    
    print(f"Regular Days: €{regular_avg:6,.0f} (baseline)")
    
    # Category-wise analysis
    print(f"\nHoliday Impact by {category_col.title()}:")
    print("-" * 35)
    
    categories = sorted(df[category_col].unique())
    for category in categories:
        regular = df_open[(df_open[category_col] == category) & (df_open['stateholiday'] == 'Normal Day')][target_col].mean()
        holiday = df_open[(df_open[category_col] == category) & (df_open['stateholiday'] != 'Normal Day')][target_col].mean()
        
        if not pd.isna(regular):
            currency = "€" if target_col == 'sales' else ""
            if not pd.isna(holiday):
                impact = ((holiday - regular) / regular) * 100
                print(f"{str(category):12}: Regular {currency}{regular:6,.0f} | Holiday {currency}{holiday:6,.0f} | Impact {impact:+5.1f}%")
            else:
                print(f"{str(category):12}: Regular {currency}{regular:6,.0f} | No holiday data")
    
    # Store closure analysis
    total_records = len(df)
    closed_stores = len(df[df[target_col] == 0])
    holiday_closures = len(df[(df['stateholiday'] != 'Normal Day') & (df[target_col] == 0)])
    regular_closures = len(df[(df['stateholiday'] == 'Normal Day') & (df[target_col] == 0)])
    
    print(f"\nStore Operations Impact:")
    print("-" * 25)
    print(f"Total store closures: {closed_stores:,} ({(closed_stores/total_records)*100:.1f}%)")
    print(f"Holiday closures: {holiday_closures:,}")
    print(f"Regular closures: {regular_closures:,}")
    
    return summary
