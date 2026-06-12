-- This model demonstrates how to handle metrics that need different levels of aggregation
-- (e.g., percentage calculations where numerator and denominator have different grain).
--
-- Problem: When calculating "% of accounts with Won deals by segment and plan",
-- the denominator (total accounts per segment) should NOT be affected by the plan dimension.
-- But a join-then-group approach means sparse combinations (e.g., a segment
-- with no deals for a given plan) can produce incorrect results.
--
-- Solution: Pre-compute the coarser-grain metric (total accounts per segment) in dbt,
-- so it is always correct regardless of which dimensions are selected.

with accounts as (
    select * from {{ ref('accounts') }}
),

deals as (
    select * from {{ ref('deals') }}
),

-- Get total accounts per segment (the "coarser grain" metric)
segment_totals as (
    select
        segment,
        count(distinct account_id) as total_accounts_in_segment
    from accounts
    group by segment
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
    st.total_accounts_in_segment
from account_deals ad
left join segment_totals st on ad.segment = st.segment
