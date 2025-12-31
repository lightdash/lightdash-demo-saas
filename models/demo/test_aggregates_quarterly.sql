{{ config(
    tags=['test_customer_issue']
) }}

-- Aggregate model for quarterly calculations
WITH base_data AS (
  SELECT * FROM {{ ref('test_bookkeeping') }}
),

quarterly_aggregates AS (
  SELECT
    EXTRACT(YEAR FROM entry_date) AS year,
    EXTRACT(QUARTER FROM entry_date) AS quarter,
    SUM(amount * COALESCE(analytical_tag_rate, 1)) AS quarter_amount
  FROM base_data
  GROUP BY 1, 2
),

with_previous AS (
  SELECT
    year,
    quarter,
    quarter_amount,
    LAG(quarter_amount) OVER (ORDER BY year, quarter) AS prev_quarter_amount
  FROM quarterly_aggregates
)

SELECT * FROM with_previous
