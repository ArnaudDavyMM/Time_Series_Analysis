@pytest.fixture
def sample_data():
    return pd.DataFrame({
        'store': ['A', 'B', 'C', 'D'],
        'date': pd.date_range(start='2023-01-01', periods=4, freq='D'),
        'sales': [2500, 3000, 1500, 4000],
        'promotion': [True, False, True, False],
        'holiday': [False, True, False, True]
    })

