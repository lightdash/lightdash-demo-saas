{{ config(
    tags=['octo-demo']
) }}

select
    t.user_id,
    t.id as event_id,
    t.name as event_name,
    timestamp
from 
    {{ ref('stg_user_tracks') }} t
