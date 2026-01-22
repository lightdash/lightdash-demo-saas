{{ config(
    tags=['closerate_kevin', 'tori', 'geography', 'maps']
) }}

WITH source_data AS (
    SELECT * FROM {{ ref('world_country_metrics_raw') }}
),

final AS (

  SELECT
    country_code                                 -- primary key (ISO 3166-1 alpha-3)
    , country_name
    , continent
    , customer_count
    , annual_revenue_usd
    , avg_deal_size_usd
    , market_penetration_pct
    , yoy_growth_pct

  FROM source_data

)

SELECT * FROM final
