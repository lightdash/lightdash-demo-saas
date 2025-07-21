with total_deal_value as ( 
    select 
        account_id,
        sum(case when stage = 'Won' then amount else 0 end) as total_won_amount
    from 
        {{ ref('deals_raw') }}
    group by 
        account_id
)
select
    a.account_id,
    a.account_name,
    a.industry,
    segment, 
    tdv.total_won_amount
from 
    {{ ref('accounts_raw') }} as a 
left join 
    total_deal_value as tdv
on 
    a.account_id = tdv.account_id

