-- LOD Demo: Dynamic benchmarks unaffected by filters
--
-- This model demonstrates the need for metrics that remain constant
-- regardless of which dimension filters are applied.
--
-- Scenario: You want to show each plan's win rate alongside the
-- overall win rate benchmark. When a user filters to a specific plan,
-- the benchmark should NOT change — it should always reflect the
-- overall win rate across ALL plans.
--
-- Current behavior: If you add a filter for plan = 'Basic', both
-- the plan's win rate AND the benchmark get filtered, making the
-- benchmark useless (it just equals the filtered value).
--
-- With LOD FIXED, you could define:
--   overall_win_rate:
--     type: number
--     lod:
--       fixed: []  # empty = ignore ALL dimensions/filters
--     sql: ${won_deals} / NULLIF(${closed_deals}, 0)
--
-- Workaround: Pre-compute the benchmark in dbt and store it on every row.
-- This works but is static — it won't update dynamically with date filters.
--
-- Related customers: Wellthy (benchmark unaffected by person filter), Circula (targets at monthly grain)
-- Related issues: GitHub #16181

with deals as (
    select * from {{ ref('deals') }}
),

-- Calculate win rate per plan (the filtered metric)
plan_metrics as (
    select
        plan,
        count(distinct case when stage = 'Won' then deal_id end) as won_deals,
        count(distinct case when stage = 'Lost' then deal_id end) as lost_deals,
        count(distinct case when stage in ('Won', 'Lost') then deal_id end) as closed_deals,
        count(distinct deal_id) as total_deals
    from deals
    group by plan
),

-- Calculate overall win rate (the benchmark — should be unaffected by plan filter)
overall_benchmark as (
    select
        count(distinct case when stage = 'Won' then deal_id end) as overall_won_deals,
        count(distinct case when stage in ('Won', 'Lost') then deal_id end) as overall_closed_deals
    from deals
)

select
    pm.plan,
    pm.won_deals,
    pm.lost_deals,
    pm.closed_deals,
    pm.total_deals,
    ob.overall_won_deals,
    ob.overall_closed_deals
from plan_metrics pm
cross join overall_benchmark ob
