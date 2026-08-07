{{ config(
    tags=['octo-demo']
) }}
select 
    * 
from
    {{ ref('stg_users') }}