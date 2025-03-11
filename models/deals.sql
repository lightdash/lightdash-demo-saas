
select 
    deal_id,
    account_id,
    stage,
    plan,
    seats,
    amount,
    created_date
from 
    {{ ref('deals_raw') }}
