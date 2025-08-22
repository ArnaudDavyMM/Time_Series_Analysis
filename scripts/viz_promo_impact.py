import pandas as pd
import numpy as np
import plotly.io as pio
import plotly.express as px
pio.renderers.default = "notebook+plotly_mimetype"

def analyze_promotion_impact(df, target_col='sales', category_col='day', width=1200, height=500):
    """
    Analyze promotion impact across any category (day, month, store, etc.)
    
    Parameters:
    - df: DataFrame with 'promo' column
    - target_col: metric to analyze ('sales' or 'customers')
    - category_col: grouping category ('day', 'month', 'store', etc.)
    """
    # Filter out closed stores (e.g., sales = 0) for unbiased and fair comparison
    df = df[df[target_col] > 0].copy()
    
    # Create summary data
    summary = df.groupby([category_col, 'promo'])[target_col].mean().reset_index()
    
    # Visualization
    fig = px.bar(
        summary,
        x=category_col,
        y=target_col,
        color='promo',
        title=f'Promotion Impact: {target_col.title()} by {category_col.title()}',
        color_discrete_map={'Promo': '#636EFA', 'No Promo': '#EF553B'},
        barmode='group'
    )
    fig.update_layout(title_x=0.5, height=height, width=width)
    fig.show(config={'displayModeBar': True, 'displaylogo': False})
    
    # Impact analysis
    print(f"Promotion Impact Analysis - {target_col.title()} by {category_col.title()}:")
    print("=" * 60)
    
    categories = sorted(df[category_col].unique())
    for category in categories:
        no_promo = df[(df[category_col] == category) & (df['promo'] == 'No Promo')][target_col].mean()
        promo = df[(df[category_col] == category) & (df['promo'] == 'Promo')][target_col].mean()
        
        if not pd.isna(no_promo) and not pd.isna(promo):
            lift = ((promo - no_promo) / no_promo) * 100
            currency = "€" if target_col == 'sales' else ""
            print(f"{str(category):12}: No Promo {currency}{no_promo:6,.0f} | Promo {currency}{promo:6,.0f} | Lift {lift:+5.1f}%")
    
    # Overall summary
    overall_no_promo = df[df['promo'] == 'No Promo'][target_col].mean()
    overall_promo = df[df['promo'] == 'Promo'][target_col].mean()
    overall_lift = ((overall_promo - overall_no_promo) / overall_no_promo) * 100
    currency = "€" if target_col == 'sales' else ""
    
    print(f"\nOverall Impact:")
    print(f"Average lift from promotions: {overall_lift:+.1f}%")
    print(f"Additional revenue per day: {currency}{overall_promo - overall_no_promo:,.0f}")
    
    return summary
