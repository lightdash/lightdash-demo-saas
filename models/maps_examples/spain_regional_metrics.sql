{{ config(
    tags=['closerate_kevin', 'tori', 'geography', 'maps']
) }}

WITH source_data AS (
    SELECT * FROM {{ ref('spain_regional_metrics_raw') }}
),

final AS (

  SELECT
    region_code                                  -- primary key (ISO 3166-2:ES)
    , region_name
    , capital_city
    , latitude
    , longitude
    , customer_count
    , annual_revenue_eur
    , employee_count
    , market_penetration_pct
    , yoy_growth_pct

  FROM source_data

)

SELECT * FROM final
