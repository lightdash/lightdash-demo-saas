
select
    account_id,
    account_name,
    industry,
    segment,
    estimated_annual_recurring_revenue,
    case
        when estimated_annual_recurring_revenue < 1000000 then 'Small (< $1M)'
        when estimated_annual_recurring_revenue < 10000000 then 'Medium ($1M-$10M)'
        else 'Large ($10M+)'
    end as arr_band
from
    {{ ref('accounts_raw') }}
