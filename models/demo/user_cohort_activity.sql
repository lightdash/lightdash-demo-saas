with last_event as (
    select max(date(timestamp)) as last_event_date
    from {{ ref('tracks') }}
),

user_last_active as (
    select
        user_id,
        max(case when is_active then days_since_signup end) as last_active_day
    from {{ ref('user_daily_activity') }}
    group by 1
    having max(case when is_active then days_since_signup end) is not null
)

select
    uda.date_day,
    uda.user_id,
    uda.user_created_date,
    date_trunc(uda.user_created_date, month) as cohort_month,
    uda.days_since_signup,
    uda.is_active,
    uda.days_since_signup <= ula.last_active_day as is_retained,
    count(distinct uda.user_id) over (partition by date_trunc(uda.user_created_date, month)) as cohort_total_users
from {{ ref('user_daily_activity') }} uda
inner join user_last_active ula on uda.user_id = ula.user_id
cross join last_event le
where uda.date_day < le.last_event_date
