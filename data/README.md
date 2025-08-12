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
