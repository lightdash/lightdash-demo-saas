
select
    t.user_id,
    t.event_id as id,
    t.event_name as name,
    -- this code keeps the date fields relevant for the demo environment
    -- it adds the difference between the current date and a fixed date (2025-01-01)
    -- to the original date fields, effectively shifting them into the future
    {{ date_add_cross_db('t.event_timestamp', date_diff_cross_db('current_date()', '\'2025-01-01\'', 'day')) }} as timestamp
from 
    {{ ref('tracks_raw') }} t

-- the below cleans synthetically created data
-- left join {{ ref('users_raw') }} u on t.user_id = u.user_id
-- where u.first_logged_in_at < t.event_timestamp