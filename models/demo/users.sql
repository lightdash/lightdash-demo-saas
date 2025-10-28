
with cleaned_data as (
    select
        user_id AS USER_ID,
        account_id,
        email,
        job_title,
        case when is_marketing_opted_in = 1 then true else false end as is_marketing_opted_in,
        created_at,
        first_logged_in_at,
        experience_in_years,
        -- the below cleans synthetically created data
        case   
            when latest_logged_in_at < first_logged_in_at then first_logged_in_at
            when latest_logged_in_at > '2024-12-31 11:52:45' then '2024-12-31 11:52:45'
            else latest_logged_in_at
        end as latest_logged_in_at
    from 
        {{ ref('users_raw') }}
)

select
    USER_ID,
    account_id,
    email,
    job_title,
    is_marketing_opted_in,
    experience_in_years,
    -- this code keeps the date fields relevant for the demo environment
    -- it adds the difference between the current date and a fixed date (2025-01-01)
    -- to the original date fields, effectively shifting them into the future
    {{ date_add_cross_db('created_at', date_diff_cross_db('current_date()', '\'2025-01-01\'', 'day')) }} as created_at,
    {{ date_add_cross_db('first_logged_in_at', date_diff_cross_db('current_date()', '\'2025-01-01\'', 'day')) }} as first_logged_in_at,
    {{ date_add_cross_db('latest_logged_in_at', date_diff_cross_db('current_date()', '\'2025-01-01\'', 'day')) }} as latest_logged_in_at
from 
    cleaned_data