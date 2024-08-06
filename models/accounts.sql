{{
  config(
    materialized='table'
  )
}}

select *
from `lightdash-analytics.lightdash_demo_saas.accounts_raw`
