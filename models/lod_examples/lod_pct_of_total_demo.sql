-- LOD Demo: "Percentage of total with different denominator grain"
--
-- This model demonstrates the problem that LOD EXCLUDE is designed to solve.
--
-- Scenario: You want "% of customers purchasing each product" where:
--   Numerator = customers who purchased that product (per product)
--   Denominator = total customers across all regions (should IGNORE product_name)
--
-- The data is SPARSE: Product B is only sold in the North region.
-- When Lightdash groups by product_name, Product B has no South row,
-- so the denominator incorrectly drops South's 2 customers.
--
-- Correct results:
--   Product A: 4 purchasing / 12 total = 33.3%
--   Product B: 2 purchasing / 12 total = 16.7%
--
-- Broken results (current behavior without LOD):
--   Product A: 4 purchasing / 12 total = 33.3%  (happens to be correct because Product A spans all regions)
--   Product B: 2 purchasing / 10 total = 20.0%   (WRONG — South's 2 customers lost due to sparsity)
--
-- Related issues:
--   GitHub #16181 — LOD spec and pv-judit's SQL examples
--   GitHub #19665 — percent_of_total + count_distinct bug

with customers as (
    select * from {{ ref('product_region_customers_raw') }}
),

purchases as (
    select * from {{ ref('product_purchases_raw') }}
),

-- Pre-compute total customers per region (the coarser-grain denominator)
region_totals as (
    select
        region,
        count(distinct customer_id) as total_customers_in_region
    from customers
    group by region
),

-- Get product sales at the product/region grain
product_region_sales as (
    select
        p.product_name,
        c.region,
        count(distinct p.customer_id) as customers_purchasing
    from purchases p
    inner join customers c on p.customer_id = c.customer_id
    group by p.product_name, c.region
)

-- Join product sales with region totals
-- This is where sparsity causes the problem:
-- Product B has no South row, so when grouped by product_name,
-- SUM(total_customers_in_region) for Product B = 10 instead of 12
select
    ps.product_name,
    ps.region,
    ps.customers_purchasing,
    rt.total_customers_in_region
from product_region_sales ps
left join region_totals rt on ps.region = rt.region
