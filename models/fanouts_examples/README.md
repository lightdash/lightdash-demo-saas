# Fanout Examples Models
Here are examples of the different joins which can cause SQL fanouts also known as metric inflation.
I have created copies of the models we use in the SaaS demo in the `fanouts_examples` folder and with the prefix `fanouts_`. These models include:

- fanouts_accounts
- fanouts_deals
- fanouts_users
- fanouts_tracks
- fanouts_addresses

### Entity Relationship Diagram
```
ACCOUNTS (Companies) 
    ↓ account_id
    ├─► DEALS (Sales Pipeline) [1:many]
    │     ↓ (accounts.segment/industry + deals.created_at quarter)
    │     └─► SALES_TARGETS (Quarterly Goals) [many:1]
    └─► USERS (Individual Contacts) [1:many]
            ↓ user_id + valid_to is NULL
            ├─► ADDRESSES (User Addresses) [1:1]
            │     ↓ country_iso_code
            │     └─► COUNTRIES (Country Reference) [many:1]
            └─► TRACKS (Product Usage) [1:many]
```
The SQL joins have been defined in the `fanouts_accounts.yml` file and enable the use of the different dimensions and metrics from each of these models in Lightdash. 

The next section details examples of SQL fanouts. I have defined metrics for each model as follows:

Metrics safe from fanouts, these metrics are prefixed with FANOUT SAFE: 

- *unique counts*: will always return a count of unique values which is FANOUT SAFE
o tracks.  
- *min* / *max*: will always return the minimum or maximum values no matter the number of times the rows are inflated. 

Metrics affected by fanouts, these metrics are prexied with INFLATED: 

- *counts*: these metrics are only inflated if the data is not at the grain of source table e.g. the count(user_id) metric will be inflated if the users table is joined t
- *average*: the average is affected because not all rows are inflated equally.
- *sum*: adding values that are inflated will result in the incorrect sum. 
- *median*: calculating the median on inflated result will give the incorrect median value. 

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

## 5. One-to-One Joins

**Description:** This model demonstrates a one-to-one relationship where `users` is joined to `addresses` with a 1:1 relationship. Each user has exactly one address.

**Relationship:** 1 user to 1 address

**Data Grain:** The grain remains at the user level since it's a 1:1 join, so metrics from both tables should remain accurate without inflation.

### Example 5: Users → Addresses (1:1 Join)

**Selected columns:**
- `fanouts_users.unique_user_count`
- `fanouts_users.inflated_user_count`
- `fanouts_addresses.country`

**Key insights:**
- In a true 1:1 join, there should be **no fanout** - each user appears exactly once
- The `unique_user_count` should equal the `inflated_user_count` since no duplication occurs
- Users without addresses will still appear (due to LEFT JOIN) but with NULL address fields
- This is the safest type of join for metric accuracy since it preserves the original grain
- Address-based grouping (by city, state, country) maintains accurate user counts

![Example 5: One-to-One Join](image5.png)

## 6. Many-to-One Joins

**Description:** This model demonstrates a many-to-one relationship where `addresses` is joined to `countries` with a many:1 relationship. Many addresses can belong to the same country.

**Relationship:** Many addresses to 1 country

**Data Grain:** The grain remains at the address level since we're starting from addresses, so address metrics remain accurate. Country metrics will be duplicated across all addresses in that country.

### Example 6: Addresses → Countries (Many:1 Join)

**Selected columns:**
- `fanouts_addresses.city`
- `fanouts_addresses.unique_address_count`
- `fanouts_addresses.inflated_address_count`
- `fanouts_countries.country_name`
- `fanouts_countries.unique_country_count`
- `fanouts_countries.inflated_country_count`

**Key insights:**
- **No fanout occurs** for the "many" side (addresses) - each address appears exactly once
- **Fanout occurs** for the "one" side (countries) - each country appears once for every address in that country
- The `unique_address_count` equals `inflated_address_count` since addresses aren't duplicated
- The `inflated_country_count` shows how many addresses exist in each country (country records are duplicated)
- For example: If USA has 1,000 addresses, the country "USA" will appear 1,000 times in the result set
- This is the **reverse** of the typical fanout pattern - here the "one" side gets inflated, not the "many" side
- Country-level metrics (like `inflated_country_count`) will be incorrect, while address-level metrics remain accurate

## Key Takeaways

- **Fanout occurs** when joining tables with 1-to-many relationships, causing "parent" records to be duplicated
- **Chained joins amplify fanout** - each additional 1-to-many relationship multiplies the inflation effect
- **Parallel joins create Cartesian products** at the account level - every combination of related records within each account
- **Left joins preserve** all records from the left table, even when there are no matching records on the right
- **Count metrics** only reflect actual relationships - NULL values from unmatched left join records don't get counted
- **Data grain matters** - understanding which table determines your final row count is crucial for interpreting metrics correctly