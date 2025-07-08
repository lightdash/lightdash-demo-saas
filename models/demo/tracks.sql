
select
    t.user_id,
    t.event_id as id,
    t.event_name as name,
    t.event_timestamp as timestamp
from 
    {{ ref('tracks_raw') }} t