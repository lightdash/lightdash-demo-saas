{{ config(
    tags=['tori']
) }}

with accounts as (
    select * from {{ ref('accounts') }}
),

deals_agg as (
    select
        account_id,
        COUNT(DISTINCT deal_id) as total_deals,
        COUNT(DISTINCT CASE WHEN stage = 'Won' THEN deal_id END) as won_deals,
        COUNT(DISTINCT CASE WHEN stage = 'Lost' THEN deal_id END) as lost_deals,
        COUNT(DISTINCT CASE WHEN stage NOT IN ('Won', 'Lost') THEN deal_id END) as open_deals,
        SUM(amount) as total_pipeline_amount,
        SUM(CASE WHEN stage = 'Won' THEN amount ELSE 0 END) as won_amount,
        AVG(amount) as average_deal_amount,
        SUM(seats) as total_seats,
        MIN(created_date) as first_deal_date,
        MAX(created_date) as latest_deal_date
    from {{ ref('deals') }}
    group by 1
),

users_agg as (
    select
        account_id,
        COUNT(DISTINCT user_id) as total_users,
        COUNT(DISTINCT CASE WHEN is_marketing_opted_in THEN user_id END) as marketing_opted_in_users,
        MIN(created_at) as first_user_created_at,
        MAX(latest_logged_in_at) as latest_user_login,
        AVG(experience_in_years) as average_user_experience_years
    from {{ ref('users') }}
    group by 1
),

leads_agg as (
    select
        d.account_id,
        COUNT(DISTINCT l.lead_id) as total_leads,
        COUNT(DISTINCT CASE WHEN l.lead_status = 'Converted' THEN l.lead_id END) as converted_leads,
        SUM(l.lead_cost) as total_lead_cost
    from {{ ref('leads') }} l
    inner join {{ ref('deals') }} d on l.deal_id = d.deal_id
    group by 1
),

activities_agg as (
    select
        d.account_id,
        COUNT(DISTINCT a.activity_id) as total_activities,
        COUNT(DISTINCT CASE WHEN a.activity_type = 'Call' THEN a.activity_id END) as call_activities,
        COUNT(DISTINCT CASE WHEN a.activity_type = 'Email' THEN a.activity_id END) as email_activities,
        SUM(a.call_duration_seconds) as total_call_duration_seconds
    from {{ ref('activities') }} a
    inner join {{ ref('deals') }} d on a.deal_id = d.deal_id
    group by 1
),

tracks_agg as (
    select
        u.account_id,
        COUNT(DISTINCT t.id) as total_events,
        COUNT(DISTINCT t.user_id) as active_users,
        MAX(t.timestamp) as latest_event_timestamp
    from {{ ref('tracks') }} t
    inner join {{ ref('users') }} u on t.user_id = u.user_id
    group by 1
)

select
    -- account attributes
    a.account_id,
    a.account_name,
    a.industry,
    a.segment,
    a.estimated_annual_recurring_revenue,

    -- deal metrics
    COALESCE(d.total_deals, 0) as total_deals,
    COALESCE(d.won_deals, 0) as won_deals,
    COALESCE(d.lost_deals, 0) as lost_deals,
    COALESCE(d.open_deals, 0) as open_deals,
    COALESCE(d.total_pipeline_amount, 0) as total_pipeline_amount,
    COALESCE(d.won_amount, 0) as won_amount,
    d.average_deal_amount,
    COALESCE(d.total_seats, 0) as total_seats,
    d.first_deal_date,
    d.latest_deal_date,

    -- user metrics
    COALESCE(u.total_users, 0) as total_users,
    COALESCE(u.marketing_opted_in_users, 0) as marketing_opted_in_users,
    u.first_user_created_at,
    u.latest_user_login,
    u.average_user_experience_years,

    -- lead metrics
    COALESCE(l.total_leads, 0) as total_leads,
    COALESCE(l.converted_leads, 0) as converted_leads,
    COALESCE(l.total_lead_cost, 0) as total_lead_cost,

    -- activity metrics
    COALESCE(act.total_activities, 0) as total_activities,
    COALESCE(act.call_activities, 0) as call_activities,
    COALESCE(act.email_activities, 0) as email_activities,
    COALESCE(act.total_call_duration_seconds, 0) as total_call_duration_seconds,

    -- product usage metrics
    COALESCE(t.total_events, 0) as total_events,
    COALESCE(t.active_users, 0) as active_users,
    t.latest_event_timestamp

from accounts a
left join deals_agg d on a.account_id = d.account_id
left join users_agg u on a.account_id = u.account_id
left join leads_agg l on a.account_id = l.account_id
left join activities_agg act on a.account_id = act.account_id
left join tracks_agg t on a.account_id = t.account_id
