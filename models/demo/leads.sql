
WITH source_data AS ( SELECT * FROM {{ ref ('marketing_leads') }}

), final AS (

  SELECT 
    CAST(lead_id AS STRING) AS lead_id   -- primary key
    , user_id   AS USER_ID                          -- foriegn key to users table
    , deal_id                            -- foriegn key to deals table
    , {{ date_add_cross_db('CAST(created_at AS TIMESTAMP)', date_diff_cross_db('current_date()', '\'2025-10-10\'', 'day')) }} as created_at
    , {{ date_add_cross_db('CAST(converted_at AS TIMESTAMP)', date_diff_cross_db('current_date()', '\'2025-10-10\'', 'day')) }} as converted_at  -- to take care of the static dates in the demo data
    , lead_source
    , campaign_name
    , utm_medium
    , sdr
    , industry
    , lead_status
    , lead_cost

  FROM source_data

) SELECT * FROM final
