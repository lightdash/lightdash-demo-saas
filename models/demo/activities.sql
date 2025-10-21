
select
    activity_id,
    CAST(lead_id AS STRING) AS lead_id,
    sdr_name,
    activity_type, 
    activity_channel,
    activity_timestamp,
    call_duration_seconds,
    notes
from 
    {{ ref('activities_raw') }}
