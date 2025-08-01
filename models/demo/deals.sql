
select 
    deal_id,
    account_id,
    stage,
    plan,
    seats,
    amount,
    sum(case when stage = 'won' then amount else 0 end) over (partition by account_id) as total_won_amount_per_account,
    -- this code keeps the date fields relevant for the demo environment
    -- it adds the difference between the current date and a fixed date (2025-01-01)
    -- to the original date fields, effectively shifting them into the future
    {{ date_add_cross_db('created_date', date_diff_cross_db('current_date()', '\'2025-01-01\'', 'day')) }} as created_date
from 
    {{ ref('deals_raw') }}
