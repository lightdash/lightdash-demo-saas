{{ config(
    tags=['test_customer_issue']
) }}

-- Aggregate model for quarterly calculations
-- Groups by family and analytical_tag_name to calculate QoQ growth per tag
WITH base_data AS (
  SELECT * FROM {{ ref('test_bookkeeping') }}
),

quarterly_aggregates AS (
  SELECT
    family,
    analytical_tag_name,
    EXTRACT(YEAR FROM entry_date) AS year,
    EXTRACT(QUARTER FROM entry_date) AS quarter,
    SUM(amount * COALESCE(analytical_tag_rate, 1)) AS quarter_amount
  FROM base_data
  GROUP BY 1, 2, 3, 4
),

with_previous AS (
  SELECT
    family,
    analytical_tag_name,
    year,
    quarter,
    quarter_amount,
    LAG(quarter_amount) OVER (PARTITION BY family, analytical_tag_name ORDER BY year, quarter) AS prev_quarter_amount
  FROM quarterly_aggregates
)

SELECT
  *,
  -- Dummy column for calculated metric in Lightdash
  -- The actual QoQ growth will be calculated in Lightdash from aggregated metrics
  NULL AS qoq_growth_calc
FROM with_previous
