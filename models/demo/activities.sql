WITH activities_raw AS (

  SELECT
    activity_id
    , lead_id
    , sdr_name
    , activity_type
    , activity_channel
    , activity_timestamp
    , call_duration_seconds
    , notes

  FROM {{ ref('activities_raw') }}

), 

leads_raw AS (

  SELECT
    lead_id
    , deal_id

  FROM {{ ref('leads') }}

), 

final AS (

  SELECT
    a.activity_id
    , CAST(a.lead_id AS STRING) AS lead_id
    , a.sdr_name
    , a.activity_type
    , a.activity_channel
    , a.activity_timestamp
    , a.call_duration_seconds
    , a.notes
    , l.deal_id

  FROM activities_raw a
    LEFT JOIN leads_raw l
      ON CAST(a.lead_id as string) = l.lead_id

) 

SELECT * FROM final
