
  
    

    create or replace table `lightdash-analytics`.`dbt_jake`.`tictasktoe_accounts`
      
    
    

    OPTIONS()
    as (
      select *
from `lightdash-analytics.lightdash_demo_saas.accounts`
    );
  