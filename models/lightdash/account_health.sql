
{{
  config(
    tags=['created-by-lightdash']
  )
}}
  
with won_revenue as (

    select
        account_id,
        count(distinct deal_id) as won_deals,
        sum(amount) as total_won_amount,
        sum(seats) as total_seats_sold
    from lightdash_demo_saas.deals
    where stage = 'Won'
    group by 1

),

recent_engagement as (

    select
        u.account_id,
        count(distinct t.user_id) as active_users_last_90d,
        count(t.id) as events_last_90d
    from lightdash_demo_saas.tracks t
    inner join lightdash_demo_saas.users u
        on t.user_id = u.user_id
    where t.timestamp >= timestamp_sub(current_timestamp(), interval 90 day)
    group by 1

),

account_health as (

    select
        a.account_id,
        a.account_name,
        a.industry,
        a.segment,
        coalesce(w.won_deals, 0) as won_deals,
        coalesce(w.total_won_amount, 0) as total_won_amount,
        coalesce(w.total_seats_sold, 0) as total_seats_sold,
        coalesce(e.active_users_last_90d, 0) as active_users_last_90d,
        coalesce(e.events_last_90d, 0) as events_last_90d,
        safe_divide(w.total_won_amount, w.total_seats_sold) as revenue_per_seat,
        safe_divide(e.active_users_last_90d, w.total_seats_sold) as seat_utilisation
    from lightdash_demo_saas.accounts a
    left join won_revenue w on a.account_id = w.account_id
    left join recent_engagement e on a.account_id = e.account_id

)

select *
from account_health
order by total_won_amount desc
