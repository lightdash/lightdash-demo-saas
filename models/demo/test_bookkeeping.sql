{{ config(
    tags=['test_customer_issue']
) }}

-- Base model to replicate customer's bookkeeping entries
-- Data designed to show the subtotal aggregation issue
-- Matches the hierarchical Family > Tag structure from the customer's screenshot
WITH test_data AS (
  -- HR Income > Product sales (Q1 2018)
  SELECT 1 AS entry_id, 'HR Income' AS family, 'Product sales' AS analytical_tag_name, 80000.00 AS amount, 1.0 AS analytical_tag_rate, DATE('2018-01-15') AS entry_date
  UNION ALL SELECT 2, 'HR Income', 'Product sales', 24000.00, 1.0, DATE('2018-01-20')

  -- HR Income > Service Sales (Q1 2018)
  UNION ALL SELECT 3, 'HR Income', 'Service Sales', 60000.00, 1.0, DATE('2018-01-25')
  UNION ALL SELECT 4, 'HR Income', 'Service Sales', 25000.00, 1.0, DATE('2018-01-28')

  -- HR Operating Expenses > Amortissement (Q1 2018)
  UNION ALL SELECT 5, 'HR Operating Expenses', 'Amortissement', -15000.00, 1.0, DATE('2018-01-10')

  -- HR Operating Expenses > COGS (Q1 2018)
  UNION ALL SELECT 6, 'HR Operating Expenses', 'COGS', -50000.00, 1.0, DATE('2018-01-12')
  UNION ALL SELECT 7, 'HR Operating Expenses', 'COGS', -60000.00, 1.0, DATE('2018-01-18')

  -- HR Operating Expenses > Equipment (Q1 2018)
  UNION ALL SELECT 8, 'HR Operating Expenses', 'Equipment', -3000.00, 1.0, DATE('2018-01-22')
  UNION ALL SELECT 9, 'HR Operating Expenses', 'Equipment', -3500.00, 1.0, DATE('2018-01-29')

  -- HR Operating Expenses > G&A (Q1 2018)
  UNION ALL SELECT 10, 'HR Operating Expenses', 'G&A', -7000.00, 1.0, DATE('2018-01-14')
  UNION ALL SELECT 11, 'HR Operating Expenses', 'G&A', -7500.00, 1.0, DATE('2018-01-24')

  -- HR Operating Expenses > Interest (Q1 2018)
  UNION ALL SELECT 12, 'HR Operating Expenses', 'Interest', -400.00, 1.0, DATE('2018-01-31')

  -- HR Operating Expenses > Brand Marketing (Q1 2018)
  UNION ALL SELECT 13, 'HR Operating Expenses', 'Brand Marketing', -2000.00, 1.0, DATE('2018-01-16')
  UNION ALL SELECT 14, 'HR Operating Expenses', 'Brand Marketing', -2500.00, 1.0, DATE('2018-01-26')

  -- ===== Q2 2018 =====
  -- HR Income > Product sales (Q2 2018) - showing growth
  UNION ALL SELECT 15, 'HR Income', 'Product sales', 120000.00, 1.0, DATE('2018-04-15')
  UNION ALL SELECT 16, 'HR Income', 'Product sales', 40000.00, 1.0, DATE('2018-04-20')

  -- HR Income > Service Sales (Q2 2018)
  UNION ALL SELECT 17, 'HR Income', 'Service Sales', 100000.00, 1.0, DATE('2018-04-25')
  UNION ALL SELECT 18, 'HR Income', 'Service Sales', 45000.00, 1.0, DATE('2018-04-28')

  -- HR Operating Expenses > Amortissement (Q2 2018)
  UNION ALL SELECT 19, 'HR Operating Expenses', 'Amortissement', -10000.00, 1.0, DATE('2018-04-10')

  -- HR Operating Expenses > COGS (Q2 2018)
  UNION ALL SELECT 20, 'HR Operating Expenses', 'COGS', -80000.00, 1.0, DATE('2018-04-12')
  UNION ALL SELECT 21, 'HR Operating Expenses', 'COGS', -70000.00, 1.0, DATE('2018-04-18')

  -- HR Operating Expenses > Equipment (Q2 2018) - decrease
  UNION ALL SELECT 22, 'HR Operating Expenses', 'Equipment', -250.00, 1.0, DATE('2018-04-22')

  -- HR Operating Expenses > G&A (Q2 2018)
  UNION ALL SELECT 23, 'HR Operating Expenses', 'G&A', -11000.00, 1.0, DATE('2018-04-14')
  UNION ALL SELECT 24, 'HR Operating Expenses', 'G&A', -11500.00, 1.0, DATE('2018-04-24')

  -- HR Operating Expenses > Interest (Q2 2018)
  UNION ALL SELECT 25, 'HR Operating Expenses', 'Interest', -365.00, 1.0, DATE('2018-04-30')

  -- HR Operating Expenses > Brand Marketing (Q2 2018)
  UNION ALL SELECT 26, 'HR Operating Expenses', 'Brand Marketing', -4000.00, 1.0, DATE('2018-04-16')
  UNION ALL SELECT 27, 'HR Operating Expenses', 'Brand Marketing', -3500.00, 1.0, DATE('2018-04-26')

  -- ===== Q3 2018 =====
  -- HR Income > Product sales (Q3 2018)
  UNION ALL SELECT 28, 'HR Income', 'Product sales', 110000.00, 1.0, DATE('2018-07-15')
  UNION ALL SELECT 29, 'HR Income', 'Product sales', 38000.00, 1.0, DATE('2018-07-20')

  -- HR Income > Service Sales (Q3 2018) - decrease
  UNION ALL SELECT 30, 'HR Income', 'Service Sales', 85000.00, 1.0, DATE('2018-07-25')
  UNION ALL SELECT 31, 'HR Income', 'Service Sales', 40000.00, 1.0, DATE('2018-07-28')

  -- HR Operating Expenses > Amortissement (Q3 2018)
  UNION ALL SELECT 32, 'HR Operating Expenses', 'Amortissement', -12000.00, 1.0, DATE('2018-07-10')

  -- HR Operating Expenses > COGS (Q3 2018) - decrease
  UNION ALL SELECT 33, 'HR Operating Expenses', 'COGS', -65000.00, 1.0, DATE('2018-07-12')
  UNION ALL SELECT 34, 'HR Operating Expenses', 'COGS', -55000.00, 1.0, DATE('2018-07-18')

  -- HR Operating Expenses > Equipment (Q3 2018)
  UNION ALL SELECT 35, 'HR Operating Expenses', 'Equipment', -7000.00, 1.0, DATE('2018-07-22')

  -- HR Operating Expenses > G&A (Q3 2018)
  UNION ALL SELECT 36, 'HR Operating Expenses', 'G&A', -13000.00, 1.0, DATE('2018-07-14')
  UNION ALL SELECT 37, 'HR Operating Expenses', 'G&A', -14500.00, 1.0, DATE('2018-07-24')

  -- HR Operating Expenses > Interest (Q3 2018)
  UNION ALL SELECT 38, 'HR Operating Expenses', 'Interest', -420.00, 1.0, DATE('2018-07-31')

  -- HR Operating Expenses > Brand Marketing (Q3 2018)
  UNION ALL SELECT 39, 'HR Operating Expenses', 'Brand Marketing', -4500.00, 1.0, DATE('2018-07-16')
  UNION ALL SELECT 40, 'HR Operating Expenses', 'Brand Marketing', -5000.00, 1.0, DATE('2018-07-26')

  -- ===== Q4 2018 =====
  -- HR Income > Product sales (Q4 2018)
  UNION ALL SELECT 41, 'HR Income', 'Product sales', 95000.00, 1.0, DATE('2018-10-15')
  UNION ALL SELECT 42, 'HR Income', 'Product sales', 35000.00, 1.0, DATE('2018-10-20')

  -- HR Income > Service Sales (Q4 2018)
  UNION ALL SELECT 43, 'HR Income', 'Service Sales', 92000.00, 1.0, DATE('2018-10-25')
  UNION ALL SELECT 44, 'HR Income', 'Service Sales', 46000.00, 1.0, DATE('2018-10-28')

  -- HR Operating Expenses > Amortissement (Q4 2018)
  UNION ALL SELECT 45, 'HR Operating Expenses', 'Amortissement', -14000.00, 1.0, DATE('2018-10-10')

  -- HR Operating Expenses > COGS (Q4 2018)
  UNION ALL SELECT 46, 'HR Operating Expenses', 'COGS', -58000.00, 1.0, DATE('2018-10-12')
  UNION ALL SELECT 47, 'HR Operating Expenses', 'COGS', -49000.00, 1.0, DATE('2018-10-18')

  -- HR Operating Expenses > Equipment (Q4 2018) - large increase
  UNION ALL SELECT 48, 'HR Operating Expenses', 'Equipment', -15000.00, 1.0, DATE('2018-10-22')
  UNION ALL SELECT 49, 'HR Operating Expenses', 'Equipment', -14500.00, 1.0, DATE('2018-10-29')

  -- HR Operating Expenses > G&A (Q4 2018)
  UNION ALL SELECT 50, 'HR Operating Expenses', 'G&A', -14000.00, 1.0, DATE('2018-10-14')
  UNION ALL SELECT 51, 'HR Operating Expenses', 'G&A', -13500.00, 1.0, DATE('2018-10-24')

  -- HR Operating Expenses > Interest (Q4 2018)
  UNION ALL SELECT 52, 'HR Operating Expenses', 'Interest', -445.00, 1.0, DATE('2018-10-31')

  -- HR Operating Expenses > Brand Marketing (Q4 2018)
  UNION ALL SELECT 53, 'HR Operating Expenses', 'Brand Marketing', -9000.00, 1.0, DATE('2018-10-16')
  UNION ALL SELECT 54, 'HR Operating Expenses', 'Brand Marketing', -9500.00, 1.0, DATE('2018-10-26')
)

SELECT * FROM test_data
