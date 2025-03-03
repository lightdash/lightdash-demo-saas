
select
    user_id,
    account_id,
    email,
    job_title,
    case when is_marketing_opted_in = 1 then true else false end as is_marketing_opted_in,
    {{ shift_timestamp('created_at') }} as created_at,
    {{ shift_timestamp('first_logged_in_at') }} as first_logged_in_at,
    -- the below cleans synthetically created data
    -- we may need to expand on this to remove latest logged in at that are before the first loggedn in at.
    case   
        when cast({{ shift_timestamp('latest_logged_in_at') }} as timestamp) > current_timestamp then current_timestamp - interval '1' day
        when cast({{ shift_timestamp('latest_logged_in_at') }} as timestamp) < cast({{ shift_timestamp('first_logged_in_at') }} as timestamp) then cast({{ shift_timestamp('first_logged_in_at') }} as timestamp)
        else cast({{ shift_timestamp('latest_logged_in_at') }} as timestamp)
    end as latest_logged_in_at
from 
    {{ ref('users_raw') }}