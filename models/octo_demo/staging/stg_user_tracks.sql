select
    t.user_id,
    t.event_id as id,
    t.event_name as name,
    -- this code keeps the date fields relevant for the demo environment
    -- it adds the difference between the current date and a fixed date (2025-01-01)
    -- to the original date fields, effectively shifting them into the future
    {{ date_add_cross_db('t.event_timestamp', date_diff_cross_db('current_date()', '\'2025-01-01\'', 'day')) }} as timestamp
from 
    {{ source('octo_demo', 'tracks_raw') }} t