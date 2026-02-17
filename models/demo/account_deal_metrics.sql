-- This model demonstrates how to handle metrics that need different levels of aggregation
-- (e.g., percentage calculations where numerator and denominator have different grain).
--
-- Problem: When calculating "% of segment deals by plan", the denominator
-- (total deals per segment) should NOT be affected by the plan dimension.
-- But a join-then-group approach means the denominator gets incorrectly
-- scoped to only deals with that specific plan.
--
-- Solution: Pre-compute the coarser-grain metric (total deals per segment) in dbt,
-- so it is always correct regardless of which dimensions are selected.

with accounts as (
    select * from {{ ref('accounts') }}
),

deals as (
    select * from {{ ref('deals') }}
),

-- Get deal-level detail joined to accounts
account_deals as (
    select
        a.account_id,
        a.account_name,
        a.segment,
        a.industry,
        d.deal_id,
        d.plan,
        d.stage,
        d.amount
    from accounts a
    inner join deals d on a.account_id = d.account_id
),

-- Get total deals per segment (the "coarser grain" metric)
segment_totals as (
    select
        segment,
        count(distinct deal_id) as total_deals_in_segment
    from account_deals
    group by segment
)

-- Final: join deal-level data with pre-computed segment totals
select
    ad.account_id,
    ad.account_name,
    ad.segment,
    ad.industry,
    ad.deal_id,
    ad.plan,
    ad.stage,
    ad.amount,
    st.total_deals_in_segment
from account_deals ad
left join segment_totals st on ad.segment = st.segment
