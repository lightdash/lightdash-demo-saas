
select 
    deal_id,
    account_id,
    stage,
    plan,
    seats,
    amount,
    -- this code keeps the date fields relevant for the demo environment
    -- it adds the difference between the current date and a fixed date (2025-01-01)
    -- to the original date fields, effectively shifting them into the future
    {{ date_add_cross_db('created_date', 'date_diff(current_date(), \'2025-01-01\', day)') }} as created_date
from 
    {{ ref('deals_raw') }}
