-- LOD Demo: percent_of_total + count_distinct bug
--
-- This model demonstrates how percent_of_total produces wrong results
-- with COUNT DISTINCT when entities belong to multiple groups.
--
-- Scenario: Customers can purchase multiple products. You want
-- "% of unique customers who purchased each product."
--
-- The bug: Lightdash computes the total as SUM of grouped counts,
-- not as a true ungrouped COUNT DISTINCT. When customers appear in
-- multiple groups, the sum of grouped counts exceeds the true total.
--
-- Data:
--   12 unique customers total
--   Product A: 4 customers (IDs 1, 2, 9, 10)
--   Product B: 2 customers (IDs 3, 4)
--   Product C: 4 customers (IDs 5, 6, 7, 8)
--   Product D: 4 customers (IDs 1, 3, 11, 12)  ← customers 1 and 3 also buy A and B!
--
-- Correct results:
--   Product A: 4 / 12 = 33.3%
--   Product B: 2 / 12 = 16.7%
--   Product C: 4 / 12 = 33.3%
--   Product D: 4 / 12 = 33.3%
--
-- Broken results (SUM of grouped counts as denominator):
--   SUM of grouped counts = 4 + 2 + 4 + 4 = 14 (wrong! actual total is 12)
--   Product A: 4 / 14 = 28.6% (wrong)
--   Product B: 2 / 14 = 14.3% (wrong)
--   Product C: 4 / 14 = 28.6% (wrong)
--   Product D: 4 / 14 = 28.6% (wrong)
--
-- The denominator is inflated because customers 1 and 3 are double-counted
-- (they appear in two product groups each).
--
-- Related issues: GitHub #19665

with customers as (
    select * from {{ ref('product_region_customers_raw') }}
),

purchases as (
    -- Original purchases (Products A and B)
    select customer_id, product_name
    from {{ ref('product_purchases_raw') }}

    union all

    -- Add Product C and Product D to demonstrate overlapping membership
    -- Product C: customers 5, 6, 7, 8
    select 5 as customer_id, 'Product C' as product_name union all
    select 6, 'Product C' union all
    select 7, 'Product C' union all
    select 8, 'Product C' union all
    -- Product D: customers 1, 3, 11, 12 (1 and 3 overlap with A and B!)
    select 1, 'Product D' union all
    select 3, 'Product D' union all
    select 11, 'Product D' union all
    select 12, 'Product D'
)

select
    p.product_name,
    p.customer_id
from purchases p
inner join customers c on p.customer_id = c.customer_id
