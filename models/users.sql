
select
    user_id,
    account_id,
    email,
    job_title,
    is_marketing_opted_in,
    created_at,
    first_logged_in_at,
    -- the below cleans synthetically created data
    case   
        when cast(latest_logged_in_at as timestamp) > current_timestamp then current_timestamp - interval '1' day
        else cast(latest_logged_in_at as timestamp)
    end as latest_logged_in_at
from 
    {{ ref('users_raw') }}