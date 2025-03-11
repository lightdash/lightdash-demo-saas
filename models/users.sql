
select
    user_id,
    account_id,
    email,
    job_title,
    case when is_marketing_opted_in = 1 then true else false end as is_marketing_opted_in,
    created_at,
    first_logged_in_at,
    -- the below cleans synthetically created data
    -- we may need to expand on this to remove latest logged in at that are before the first logged in at.
    case   
        when latest_logged_in_at > cast(current_timestamp as datetime) then cast(current_timestamp as datetime) - interval '1' day
        when latest_logged_in_at < first_logged_in_at then first_logged_in_at
        else latest_logged_in_at
    end as latest_logged_in_at
from 
    {{ ref('users_raw') }}