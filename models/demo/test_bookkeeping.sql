{{ config(
    tags=['test_customer_issue']
) }}

-- Base model to replicate customer's bookkeeping entries
-- Data designed to show the subtotal aggregation issue
WITH test_data AS (
  -- Q1 2025 entries
  SELECT
    1 AS entry_id,
    100.00 AS amount,
    DATE('2025-01-15') AS entry_date,
    'Tag A' AS analytical_tag_name,
    1.0 AS analytical_tag_rate

  UNION ALL

  SELECT
    2 AS entry_id,
    200.00 AS amount,
    DATE('2025-01-20') AS entry_date,
    'Tag B' AS analytical_tag_name,
    1.5 AS analytical_tag_rate

  UNION ALL

  SELECT
    3 AS entry_id,
    150.00 AS amount,
    DATE('2025-01-25') AS entry_date,
    'Tag A' AS analytical_tag_name,
    1.0 AS analytical_tag_rate

  -- Q2 2025 entries (more entries to show subtotal issue)
  UNION ALL

  SELECT
    4 AS entry_id,
    300.00 AS amount,
    DATE('2025-04-10') AS entry_date,
    'Tag A' AS analytical_tag_name,
    1.0 AS analytical_tag_rate

  UNION ALL

  SELECT
    5 AS entry_id,
    400.00 AS amount,
    DATE('2025-04-15') AS entry_date,
    'Tag B' AS analytical_tag_name,
    1.5 AS analytical_tag_rate

  UNION ALL

  SELECT
    6 AS entry_id,
    250.00 AS amount,
    DATE('2025-04-25') AS entry_date,
    'Tag A' AS analytical_tag_name,
    1.0 AS analytical_tag_rate

  UNION ALL

  SELECT
    7 AS entry_id,
    100.00 AS amount,
    DATE('2025-04-28') AS entry_date,
    'Tag B' AS analytical_tag_name,
    1.5 AS analytical_tag_rate
)

SELECT * FROM test_data
