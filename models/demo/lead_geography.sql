{{ config(
    tags=['closerate_kevin', 'tori', 'geography']
) }}

WITH source_data AS (
    SELECT * FROM {{ ref('lead_geographic_data') }}
),

final AS (

  SELECT
    CAST(lead_id AS STRING) AS lead_id       -- primary key, foreign key to leads
    , user_id                                 -- foreign key to users table
    , continent
    , country_name
    , country_code
    , state_or_province_name
    , state_code
    , postal_code

  FROM source_data

)

SELECT * FROM final
