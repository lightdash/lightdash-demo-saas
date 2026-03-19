
with account_deals as (
    select
        account_id,
        count(distinct deal_id) as total_deals,
        count(distinct case when stage = 'Won' then deal_id end) as won_deals,
        count(distinct case when stage = 'Lost' then deal_id end) as lost_deals,
        count(distinct case when stage not in ('Won', 'Lost') then deal_id end) as open_deals,
        sum(case when stage = 'Won' then amount else 0 end) as total_won_revenue,
        sum(amount) as total_pipeline_value,
        min(created_date) as first_deal_date,
        max(created_date) as latest_deal_date
    from
        {{ ref('deals') }}
    group by 1
),

account_users as (
    select
        account_id,
        count(distinct user_id) as total_users,
        count(distinct case when is_marketing_opted_in then user_id end) as marketing_opted_in_users,
        min(created_at) as first_user_created_at,
        max(latest_logged_in_at) as most_recent_login,
        avg(experience_in_years) as avg_user_experience
    from
        {{ ref('users') }}
    group by 1
),

account_events as (
    select
        u.account_id,
        count(distinct t.id) as total_events,
        count(distinct t.user_id) as active_users,
        count(distinct t.name) as unique_event_types,
        max(t.timestamp) as last_event_at
    from
        {{ ref('tracks') }} t
    inner join
        {{ ref('users') }} u on t.user_id = u.user_id
    group by 1
),

account_leads as (
    select
        u.account_id,
        count(distinct l.lead_id) as total_leads,
        count(distinct case when l.lead_status = 'Converted' then l.lead_id end) as converted_leads,
        sum(l.lead_cost) as total_lead_spend,
        min(l.created_at) as first_lead_date
    from
        {{ ref('leads') }} l
    inner join
        {{ ref('users') }} u on l.user_id = u.user_id
    group by 1
),

account_activities as (
    select
        d.account_id,
        count(distinct a.activity_id) as total_activities,
        count(distinct case when a.activity_type = 'Call' then a.activity_id end) as total_calls,
        count(distinct case when a.activity_type = 'Demo' then a.activity_id end) as total_demos,
        sum(a.call_duration_seconds) as total_call_seconds
    from
        {{ ref('activities') }} a
    inner join
        {{ ref('deals') }} d on a.deal_id = d.deal_id
    group by 1
)

select
    a.account_id,
    a.account_name,
    a.industry,
    a.segment,
    a.estimated_annual_recurring_revenue,

    -- deal metrics
    coalesce(d.total_deals, 0) as total_deals,
    coalesce(d.won_deals, 0) as won_deals,
    coalesce(d.lost_deals, 0) as lost_deals,
    coalesce(d.open_deals, 0) as open_deals,
    coalesce(d.total_won_revenue, 0) as total_won_revenue,
    coalesce(d.total_pipeline_value, 0) as total_pipeline_value,
    d.first_deal_date,
    d.latest_deal_date,
    SAFE_DIVIDE(d.won_deals, d.total_deals) as deal_win_rate,

    -- user metrics
    coalesce(u.total_users, 0) as total_users,
    coalesce(u.marketing_opted_in_users, 0) as marketing_opted_in_users,
    u.first_user_created_at,
    u.most_recent_login,
    u.avg_user_experience,

    -- product engagement
    coalesce(e.total_events, 0) as total_events,
    coalesce(e.active_users, 0) as active_users,
    coalesce(e.unique_event_types, 0) as unique_event_types,
    e.last_event_at,
    SAFE_DIVIDE(e.total_events, e.active_users) as events_per_active_user,

    -- lead metrics
    coalesce(l.total_leads, 0) as total_leads,
    coalesce(l.converted_leads, 0) as converted_leads,
    coalesce(l.total_lead_spend, 0) as total_lead_spend,
    l.first_lead_date,
    SAFE_DIVIDE(l.converted_leads, l.total_leads) as lead_conversion_rate,

    -- activity metrics
    coalesce(act.total_activities, 0) as total_activities,
    coalesce(act.total_calls, 0) as total_calls,
    coalesce(act.total_demos, 0) as total_demos,
    coalesce(act.total_call_seconds, 0) as total_call_seconds

from
    {{ ref('accounts') }} a
left join account_deals d on a.account_id = d.account_id
left join account_users u on a.account_id = u.account_id
left join account_events e on a.account_id = e.account_id
left join account_leads l on a.account_id = l.account_id
left join account_activities act on a.account_id = act.account_id
