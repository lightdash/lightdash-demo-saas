# Lightdash SaaS Demo

## Overview

This repository contains customer relationship data that tracks the complete journey from company acquisition through individual user engagement. The data follows a hierarchical structure designed to provide insights into sales performance, user adoption, and customer success patterns.

## Data Structure

### Entity Relationship Diagram
```
ACCOUNTS (Companies) 
    ↓ account_id
    ├─► DEALS (Sales Pipeline)
    └─► USERS (Individual Contacts)
            ↓ user_id  
            └─► TRACKS (Product Usage)
```

## Dataset Descriptions

### `accounts_raw.csv`
**Master company data** - Contains information about organizations in the sales pipeline.

| Column | Type | Description |
|--------|------|-------------|
| `account_id` | UUID | Unique company identifier (Primary Key) |
| `account_name` | String | Company/organization name |
| `industry` | String | Business sector (e.g., Financial Services, Technology, Healthcare) |
| `segment` | String | Company size category (SMB, Midmarket, Enterprise) |

### `deals_raw.csv`
**Sales pipeline data** - Tracks revenue opportunities and deal outcomes.

| Column | Type | Description |
|--------|------|-------------|
| `deal_id` | UUID | Unique deal identifier (Primary Key) |
| `account_id` | UUID | Links to accounts table (Foreign Key) |
| `stage` | String | Sales stage (Qualified, Won, Lost, PoC) |
| `plan` | String | Service plan type |
| `seats` | Integer | Number of licensed seats |
| `amount` | Integer | Deal value in dollars |
| `created_date` | Timestamp | When the deal was created |

### `users_raw.csv`
**Individual contact data** - People within organizations who use the platform.

| Column | Type | Description |
|--------|------|-------------|
| `user_id` | UUID | Unique user identifier (Primary Key) |
| `account_id` | UUID | Links to accounts table (Foreign Key) |
| `email` | String | User email address |
| `job_title` | String | Role within organization |
| `is_marketing_opted_in` | Boolean | Marketing communication preference (0/1) |
| `created_at` | Timestamp | When user account was created |
| `first_logged_in_at` | Timestamp | Initial platform access |
| `latest_logged_in_at` | Timestamp | Most recent login |

### `tracks_raw.csv`
**User activity data** - Product usage and engagement events.

| Column | Type | Description |
|--------|------|-------------|
| `user_id` | UUID | Links to users table (Foreign Key) |
| `event_id` | UUID | Unique event identifier |
| `event_name` | String | Type of action performed |
| `event_timestamp` | Timestamp | When the event occurred |

#### Common Event Types
- `login_successful` - User authentication
- `report_generated` - Report creation
- `file_downloaded` - File access
- `workspace_created` - New workspace setup
- `api_call_made` - API usage
- `integration_failed` - System integration errors

## Key Relationships

- **One-to-Many:** Each account can have multiple deals and users
- **One-to-Many:** Each user can have multiple activity tracks
- **Many-to-One:** Multiple users belong to the same account
- **Many-to-One:** Multiple deals can exist for the same account

## Analysis Capabilities

This data structure enables analysis across multiple dimensions:

### Sales Performance
- Win rates by industry and company segment
- Average deal size by company characteristics
- Sales cycle length and conversion patterns

### User Adoption
- User engagement by job role and company type
- Feature adoption rates
- Time to first value metrics

### Customer Success
- Account health scoring based on user activity
- Expansion opportunity identification
- Churn risk prediction

### Marketing Intelligence
- Lead qualification based on company characteristics
- User role targeting for campaigns
- Product usage patterns by segment

## Sample Queries

### Account Overview with Deal Summary
```sql
SELECT 
    a.account_name,
    a.industry,
    a.segment,
    COUNT(d.deal_id) as total_deals,
    SUM(d.amount) as total_pipeline_value,
    COUNT(u.user_id) as total_users
FROM accounts a
LEFT JOIN deals d ON a.account_id = d.account_id
LEFT JOIN users u ON a.account_id = u.account_id
GROUP BY a.account_id;
```

### User Engagement Analysis
```sql
SELECT 
    u.job_title,
    COUNT(DISTINCT u.user_id) as user_count,
    COUNT(t.event_id) as total_events,
    COUNT(t.event_id) / COUNT(DISTINCT u.user_id) as avg_events_per_user
FROM users u
LEFT JOIN tracks t ON u.user_id = t.user_id
GROUP BY u.job_title
ORDER BY avg_events_per_user DESC;
```
