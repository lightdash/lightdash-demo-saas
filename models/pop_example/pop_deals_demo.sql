{{ config(
    tags=['tori']
) }}

SELECT
    deal_id,
    account_id,
    stage,
    plan,
    seats,
    amount,
    created_date
FROM
    {{ ref('deals') }}
