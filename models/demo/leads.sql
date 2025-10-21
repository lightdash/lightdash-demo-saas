
WITH source_data AS ( SELECT * FROM {{ ref ('marketing_leads') }}

), final AS (

  SELECT 
    CAST(lead_id AS STRING) AS lead_id   -- primary key
    , user_id                            -- foriegn key to users table
    , deal_id                            -- foriegn key to deals table
    , created_at 
    , CAST(converted_at AS TIMESTAMP) AS converted_at
    , lead_source
    , campaign_name
    , utm_medium
    , sdr
    , industry
    , lead_status
    , lead_cost

  FROM source_data

) SELECT * FROM final
