with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="date_add(current_date(), interval 30 day)"
    ) }}
),

users as (
    select
        user_id,
        date(created_at) as user_created_date
    from {{ ref('users') }}
),

users_date_grid as (
    select
        u.user_id,
        u.user_created_date,
        d.date_day
    from users u
    cross join date_spine d
    where d.date_day <= current_date()
      and d.date_day >= u.user_created_date
),

events as (
    select
        user_id,
        date(timestamp) as date_day
    from {{ ref('tracks') }}
    group by 1, 2
)

select
    g.date_day,
    g.user_id,
    g.user_created_date,
    date_diff(g.date_day, g.user_created_date, day) as days_since_signup,
    events.user_id is not null as is_active
from users_date_grid g
left join events
    on g.user_id = events.user_id
    and g.date_day = events.date_day
