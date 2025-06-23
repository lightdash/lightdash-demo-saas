# Fanout Examples Models
Here are examples of the different joins we get with metric inflation included.
I have created copies of the models we use in the SaaS demo in the `fanouts_examples` folder and with the prefix `fanouts_`. These models include:

fanouts_accounts
fanouts_deals
fanouts_users
fanouts_tracks

Here are examples of metric inflation:

## 1. Single 1-to-Many Joins

**Description:** These models demonstrate single 1-to-many relationships where `accounts` is joined to another table with a one-to-many relationship.

**Relationship:** 1 account to many related records.

**Data Grain:** There is a row per related record meaning that metrics for the related table are correct while account metrics that do not apply deduplication techniques will be inflated.

### Example 1: Accounts → Deals

**Selected columns:**
- `fanouts_accounts.segment`
- `fanouts_accounts.unique_account_count`
- `fanouts_accounts.inflated_account_count`
- `fanout_deals.unique_deal_count`
- `fanout_deals.inflated_deal_count`

**Key insights:**
- Metric inflation only happens when you select metrics from both joined tables
- The `inflated_account_count` (567 for SMB) shows how account records get duplicated across their associated deals
- The `inflated_account_count` nearly matches the `unique_deal_count` (565 for SMB), with the small difference indicating some accounts have no deals
- When using left joins, accounts without deals still appear in the result set but don't contribute to deal count metrics

![Example 1: Accounts → Deals](image1.png)

### Example 2: Accounts → Users

**Selected columns:**
- `fanouts_accounts.segment`
- `fanouts_accounts.unique_account_count`
- `fanouts_accounts.inflated_account_count`
- `fanout_users.unique_user_count`
- `fanout_users.inflated_user_count`

**Key insights:**
- For SMB accounts: 560 unique accounts become 3,355 rows after joining to users
- The `inflated_account_count` (3,355) shows how many times account records appear when duplicated across all their associated users
- The `inflated_user_count` (3,354) is almost identical to the `inflated_account_count` (3,355)
- The slight difference is because one account has no users - that account still appears in the result set due to the left join (contributing to the inflated account count), but since there's no associated user, it doesn't contribute to the user count metrics
- This demonstrates the classic fanout pattern: accounts get duplicated once for each user they have

![Example 2: Accounts → Users](image2.png)

## 2. Chained 1-to-Many Joins

**Description:** This model demonstrates chained 1-to-many relationships where `accounts` → `users` → `tracks` are joined together, where one account can have many users, and each user can have many tracks.

**Relationship:** 1 account to many users to many tracks (events)

**Data Grain:** There is a row per track/event meaning that track metrics are correct while account and user metrics that do not apply deduplication techniques will be inflated.

### Example 3: Accounts → Users → Tracks

**Selected columns:**
- `fanouts_accounts.segment`
- `fanouts_accounts.unique_account_count`
- `fanouts_accounts.inflated_account_count`
- `fanout_users.unique_user_count`
- `fanout_users.inflated_user_count`
- `fanout_tracks.unique_event_count`
- `fanout_tracks.inflated_event_count`

**Key insights:**
- The data is at the tracks grain, so all metrics marked as "inflated" reflect the number of rows in the tracks table
- For SMB: 560 unique accounts become 55,917 inflated rows - each account appears once for every track event across all its users
- 3,354 unique users become 55,916 inflated rows - each user appears once for every track event they have
- The `unique_event_count` equals the `inflated_event_count` (55,916) because we're already at the tracks grain
- Small differences in totals (like 55,917 vs 55,916) indicate accounts or users with no related records due to left joins
- This shows extreme fanout: a single account can appear tens of thousands of times when chained through multiple 1-to-many relationships

![Example 3: Chained Accounts → Users → Tracks](image3.png)

## 3. Parallel 1-to-Many Joins

**Description:** This model demonstrates joining `accounts` to both `deals` and `users` simultaneously using separate LEFT OUTER JOINs, creating parallel 1-to-many relationships from the same base table.

**Relationship:** 1 account to many deals AND 1 account to many users (parallel joins)

**Data Grain:** The grain is at the level of account-deal-user combinations, where each account appears once for every unique combination of its deals and users.

### Example 4: Accounts → Deals + Users (Parallel Joins)

**Selected columns:**
- `fanouts_accounts.segment`
- `fanouts_accounts.account_id`
- `fanouts_accounts.unique_account_count` 
- `fanouts_accounts.inflated_account_count`
- `fanouts_deals.unique_deal_count`
- `fanouts_deals.inflated_deal_count`
- `fanouts_users.unique_user_count`
- `fanouts_users.inflated_user_count`

**Key insights:**
- The inflated counts show account-level multiplication: for each account, rows = (deals for that account) × (users for that account)
- Example: Account with 4 deals and 6 users creates 24 rows (4×6)
- Most accounts have 1 deal and 6 users, creating 6 rows each
- The final totals are the sum of individual account-level multiplications: Σ(deals_per_account × users_per_account)
- This is NOT a simple "total deals × total users" calculation
- Each deal for an account gets paired with every user for that same account, creating a Cartesian product within account boundaries

**What happens when accounts have no users or deals:**
- **Account with 3 deals, 0 users:** Creates 3 rows (one per deal, user columns are NULL)
- **Account with 0 deals, 4 users:** Creates 4 rows (one per user, deal columns are NULL)  
- **Account with 0 deals, 0 users:** Creates 1 row (all deal and user columns are NULL)
- The account contributes to `inflated_account_count` in all cases (because the account record exists)
- It only contributes to `inflated_user_count` or `inflated_deal_count` when those relationships actually exist (NULLs aren't counted)
- Multiplication only happens when both deals AND users exist for an account

![Example 4: Parallel Joins](image4.png)

## Key Takeaways

- **Fanout occurs** when joining tables with 1-to-many relationships, causing "parent" records to be duplicated
- **Chained joins amplify fanout** - each additional 1-to-many relationship multiplies the inflation effect
- **Parallel joins create Cartesian products** at the account level - every combination of related records within each account
- **Left joins preserve** all records from the left table, even when there are no matching records on the right
- **Count metrics** only reflect actual relationships - NULL values from unmatched left join records don't get counted
- **Data grain matters** - understanding which table determines your final row count is crucial for interpreting metrics correctly