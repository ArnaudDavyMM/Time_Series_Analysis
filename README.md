📈 Time Series Forecasting for Retail Sales

The main goal of this project is to perform Time Series Analysis and forecast sales using various Machine Learning algorithms.

I divide the project into two (2) Parts. The first part is focused on Data Analysis and the second focuses on various Machine Learning.
I decided to do that separately due to computationanl power I have with google coloab in order to not exceed the GPU limit.

in sum, there will be 3 sub-project as follow:
1. Store Sales TimeSeries EDA
2. Store Sales TimeSeries Analys & Forecast using Statmodels (ARIMA, SARIMA)
3. Store Sales TimeSeries Analys & Forecast with Facebook Prophet
4. Store Sales TimeSeries Analys & Forecast with Ensemble algorithms
5. Store Sales TimeSeries Analys & Forecast with Deep Learning (Neural Network including LSTM)

🚀 HYBRID TIME SERIES ANALYSIS & FORECASTING for Retail Sales / MODERN TIME SERIES FORECASTING ALGORITHMS (UPDATING)

A robust and scalable time series forecasting framework that fuses multiple state-of-the-art models—such as Facebook Prophet, LightGBM, and others—to effectively capture both linear trends and non-linear residual patterns in retail sales data. This hybrid architecture is designed to model seasonality, holiday effects, and external regressors, while leveraging machine learning for enhanced pattern recognition and predictive performance.This implementation integrates Temporal Fusion Transformer (TFT), ARIMA, XGBoost, Prophet, and LSTM models for superior forecasting accuracy.

🎯 Hybrid Models

1. Prophet + LightGBM Hybrid
   . Architecture: Facebook Prophet for seasonality + LightGBM for feature-based boosting
   . Process:
     . Prophet models trend, seasonality, and holiday effects
     . LightGBM captures complex feature interactions and nonlinearities
     . Forecast output from Prophet used as feature input to LightGBM
     . Hybrid prediction blends statistical and machine learning insights
 . Best for: Seasonal time series with structured data and external regressors

2. Prophet + LSTM Hybrid
   . Architecture: Facebook Prophet for seasonality + LSTM for complex residuals
   . Process :
     . Prophet handles seasonality, trends and holidays
     . LSTM models residual patterns
     . Handles multiple seasonalities effectively
     . Hybrid prediction combines both approaches
   . Best for: Strong seasonal patterns with complex underlying dynamics
   
3. ARIMA + XGBoost Hybrid
   . ARIMA captures linear trends and seasonality
   . XGBoost models the residuals for non-linear patterns
   . Automatic ARIMA parameter optimization
   
4. TFT + ARIMA Hybrid
   . TFT captures complex non-linear patterns
   . ARIMA models the TFT residuals
   . Combined predictions for enhanced accuracy

5. Temporal Fusion Transformer (TFT)
   . Custom implementation with multi-head attention
   . Positional encoding for temporal patterns
   . Hyperparameter optimization using Optuna


