
select 
    deal_id,
    account_id,
    stage,
    plan,
    seats,
    amount,
    sum(amount) over (partition by deal_id) as safe_total_deal_value,
    date(created_date) as created_date
from 
    {{ ref('deals_raw') }}
