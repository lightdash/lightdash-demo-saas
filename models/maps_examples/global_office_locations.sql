{{ config(
    tags=['closerate_kevin', 'tori', 'geography', 'maps']
) }}

WITH source_data AS (
    SELECT * FROM {{ ref('global_office_locations_raw') }}
),

final AS (

  SELECT
    CAST(office_id AS STRING) AS office_id       -- primary key
    , office_name
    , city
    , country_name
    , country_code
    , region
    , latitude
    , longitude
    , annual_revenue_usd
    , employee_count
    , year_established
    , office_type

  FROM source_data

)

SELECT * FROM final
