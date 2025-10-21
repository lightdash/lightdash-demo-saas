
WITH source_data AS ( SELECT * FROM {{ ref ('marketing_leads') }}

), final AS (

  SELECT 
    CAST(lead_id AS STRING) AS lead_id   -- primary key
    , user_id                            -- foriegn key to users table
    , deal_id                            -- foriegn key to deals table
    , TIMESTAMP_ADD(CAST(created_at AS TIMESTAMP), INTERVAL DATE_DIFF(CURRENT_DATE(), DATE '2025-10-10', DAY) DAY) AS created_at      -- to take care of the static dates in the demo data
    , TIMESTAMP_ADD(CAST(converted_at AS TIMESTAMP), INTERVAL DATE_DIFF(CURRENT_DATE(), DATE '2025-10-10', DAY) DAY) AS converted_at
    , lead_source
    , campaign_name
    , utm_medium
    , sdr
    , industry
    , lead_status
    , lead_cost

  FROM source_data

) SELECT * FROM final
