with accounts as (
    select * from {{ ref('accounts') }}
),

users as (
    select * from {{ ref('users') }}
),

deals as (
    select * from {{ ref('deals') }}
),

leads as (
    select * from {{ ref('leads') }}
),

activities as (
    select * from {{ ref('activities') }}
),

tracks as (
    select * from {{ ref('tracks') }}
),

user_metrics as (
    select
        account_id,
        count(distinct user_id) as total_users,
        min(created_at) as first_user_created_at,
        max(latest_logged_in_at) as most_recent_login_at,
        avg(experience_in_years) as avg_experience_in_years,
        countif(is_marketing_opted_in) as users_opted_into_marketing
    from users
    group by 1
),

deal_metrics as (
    select
        account_id,
        count(distinct deal_id) as total_deals,
        countif(stage = 'Won') as won_deals,
        countif(stage = 'Lost') as lost_deals,
        countif(stage not in ('Won', 'Lost')) as open_deals,
        sum(amount) as total_deal_amount,
        sum(case when stage = 'Won' then amount else 0 end) as won_deal_amount,
        avg(amount) as avg_deal_amount,
        sum(seats) as total_seats,
        min(created_date) as first_deal_date,
        max(created_date) as latest_deal_date
    from deals
    group by 1
),

lead_metrics as (
    select
        u.account_id,
        count(distinct l.lead_id) as total_leads,
        countif(l.lead_status = 'converted') as converted_leads,
        countif(l.lead_status = 'qualified') as qualified_leads,
        countif(l.lead_status = 'disqualified') as disqualified_leads,
        sum(l.lead_cost) as total_lead_cost,
        min(l.created_at) as first_lead_date,
        max(l.created_at) as latest_lead_date
    from leads l
    left join users u on l.user_id = u.user_id
    where u.account_id is not null
    group by 1
),

activity_metrics as (
    select
        d.account_id,
        count(distinct a.activity_id) as total_activities,
        countif(a.activity_type = 'call_made') as total_calls,
        countif(a.activity_type = 'demo_held') as total_demos,
        countif(a.activity_type = 'contract_sent') as total_contracts_sent,
        sum(a.call_duration_seconds) as total_call_duration_seconds,
        min(a.activity_timestamp) as first_activity_date,
        max(a.activity_timestamp) as latest_activity_date
    from activities a
    left join deals d on a.deal_id = d.deal_id
    where d.account_id is not null
    group by 1
),

product_usage as (
    select
        u.account_id,
        count(distinct t.id) as total_events,
        count(distinct t.user_id) as active_users,
        min(t.timestamp) as first_event_at,
        max(t.timestamp) as latest_event_at
    from tracks t
    left join users u on t.user_id = u.user_id
    where u.account_id is not null
    group by 1
)

select
    -- Account identifiers
    a.account_id,
    a.account_name,
    a.industry,
    a.segment,
    a.estimated_annual_recurring_revenue,

    -- User metrics
    coalesce(um.total_users, 0) as total_users,
    um.first_user_created_at,
    um.most_recent_login_at,
    um.avg_experience_in_years,
    coalesce(um.users_opted_into_marketing, 0) as users_opted_into_marketing,

    -- Deal metrics
    coalesce(dm.total_deals, 0) as total_deals,
    coalesce(dm.won_deals, 0) as won_deals,
    coalesce(dm.lost_deals, 0) as lost_deals,
    coalesce(dm.open_deals, 0) as open_deals,
    coalesce(dm.total_deal_amount, 0) as total_deal_amount,
    coalesce(dm.won_deal_amount, 0) as won_deal_amount,
    dm.avg_deal_amount,
    coalesce(dm.total_seats, 0) as total_seats,
    dm.first_deal_date,
    dm.latest_deal_date,

    -- Lead metrics
    coalesce(lm.total_leads, 0) as total_leads,
    coalesce(lm.converted_leads, 0) as converted_leads,
    coalesce(lm.qualified_leads, 0) as qualified_leads,
    coalesce(lm.disqualified_leads, 0) as disqualified_leads,
    coalesce(lm.total_lead_cost, 0) as total_lead_cost,
    lm.first_lead_date,
    lm.latest_lead_date,

    -- Activity metrics
    coalesce(am.total_activities, 0) as total_activities,
    coalesce(am.total_calls, 0) as total_calls,
    coalesce(am.total_demos, 0) as total_demos,
    coalesce(am.total_contracts_sent, 0) as total_contracts_sent,
    coalesce(am.total_call_duration_seconds, 0) as total_call_duration_seconds,
    am.first_activity_date,
    am.latest_activity_date,

    -- Product usage
    coalesce(pu.total_events, 0) as total_events,
    coalesce(pu.active_users, 0) as active_users,
    pu.first_event_at,
    pu.latest_event_at,

    -- Computed fields
    SAFE_DIVIDE(dm.won_deals, dm.total_deals) as win_rate,
    SAFE_DIVIDE(lm.converted_leads, lm.total_leads) as lead_conversion_rate,
    SAFE_DIVIDE(lm.total_lead_cost, lm.converted_leads) as cost_per_converted_lead,
    SAFE_DIVIDE(pu.total_events, um.total_users) as events_per_user,
    SAFE_DIVIDE(dm.won_deal_amount, um.total_users) as revenue_per_user

from accounts a
left join user_metrics um on a.account_id = um.account_id
left join deal_metrics dm on a.account_id = dm.account_id
left join lead_metrics lm on a.account_id = lm.account_id
left join activity_metrics am on a.account_id = am.account_id
left join product_usage pu on a.account_id = pu.account_id
