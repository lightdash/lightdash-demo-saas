-- LOD Demo: Two-step aggregation
--
-- This model demonstrates the need for two-step aggregation (nested aggregates).
--
-- Scenario: You want "average number of deals per account, by segment"
--   Step 1: COUNT deals per account (fine-grain)
--   Step 2: AVG of those counts across accounts (coarser-grain)
--
-- Lightdash cannot do step 2 because metrics are always calculated at the
-- query's GROUP BY grain. There is no way to first aggregate at one level,
-- then aggregate the result at a different level.
--
-- Workaround: Pre-compute step 1 in dbt, then use AVG in Lightdash.
-- But this is inflexible — if you want a different first-step aggregation
-- (e.g., SUM of deal amounts per account, then MEDIAN), you need another model.
--
-- With LOD support, this could be expressed as:
--   AVG({FIXED account_id: COUNT(deal_id)})
--
-- Related customers: Wellthy (median projects per coordinator), Searchlight Capital
-- Related issues: GitHub #15365, #19350

with accounts as (
    select * from {{ ref('accounts') }}
),

deals as (
    select * from {{ ref('deals') }}
),

-- Step 1: Count deals per account (the inner aggregation)
deals_per_account as (
    select
        a.account_id,
        a.account_name,
        a.segment,
        a.industry,
        count(distinct d.deal_id) as deal_count
    from accounts a
    left join deals d on a.account_id = d.account_id
    group by a.account_id, a.account_name, a.segment, a.industry
)

-- This model outputs one row per account with their deal count.
-- In Lightdash, AVG(deal_count) grouped by segment gives the correct
-- "average deals per account by segment" — but ONLY because we
-- pre-computed the per-account count in dbt.
select
    account_id,
    account_name,
    segment,
    industry,
    deal_count
from deals_per_account
