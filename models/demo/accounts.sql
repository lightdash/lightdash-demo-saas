
select
    account_id,
    account_name,
    industry,
    segment, 
    estimated_annual_recurring_revenue
from 
    {{ ref('accounts_raw') }}
