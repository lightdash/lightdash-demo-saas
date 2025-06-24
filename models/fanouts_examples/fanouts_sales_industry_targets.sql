SELECT 
    target_type,
    target_value,
    quarter_start_date,
    DATE_ADD(DATE_ADD(quarter_start_date, INTERVAL 3 MONTH), INTERVAL -1 DAY) AS quarter_end_date,
    target_deals,
    target_amount
FROM {{ ref('sales_targets_raw') }}
WHERE 
    target_type = 'Industry'
   