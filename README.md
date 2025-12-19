# social-_media_network
social media network work with databse created in SQL and PostSql

PostgreSQL relational schema, data population, procedures/functions, triggers, views and sample queries for a social network platform.
# 🌐 Social Network Database — PostgreSQL Implementation
            
This project implements a **fully functional relational database** for a **Social Network platform**, designed and deployed in **PostgreSQL**.  
It includes relational schema, data population, procedures/functions, triggers, views and sample queries for a social network platform.

The goal is to model real-world social interactions such as posts, comments, reactions, messages, and user relationships — ensuring **data integrity, scalability, and realism**.
---
## Files Overview

- `schema.sql` – Base tables, constraints, indexes.
- `procedures.sql` – Stored functions, procedures, trigger functions, and trigger creation.
- `views.sql` – Reporting views (user stats, group member counts, top active users, post/chat engagement).
- `data.sql` – Bulk realistic data population (>=1000 total rows across tables).
- `queries.sql` – 20 functional example queries (CRUD + analytics).

## Requirements Coverage

- Relational schema with PK/FK and CHECK constraints.
- Integrity constraints (NOT NULL, UNIQUE, CHECK, FK, composite PKs, domain-like checks via regex and IN lists).
- Triggers (>=3): reaction count maintenance, comment count maintenance, chat last message timestamp, activity logging (extra).
- Functions / Procedures (>=4): `get_user_age`, `ban_user` (procedure), `log_activity`, `user_engagement_score`, plus trigger functions.
- Views (>=4): `vw_user_post_stats`, `vw_group_member_counts`, `vw_top_active_users`, `vw_post_engagement`, `vw_chat_activity` (extra).
- Data population script generates >1000 rows using `generate_series` and random distributions.
- 20 queries in `queries.sql`.

## Setup Instructions

### 1. Create Database
```sql
-- Run in psql (replace your role as needed)
CREATE DATABASE social_network_dev;
\c social_network_dev;
```

### 2. Run Schema
```sql
\i schema.sql
```

### 3. Load Procedures / Functions / Triggers
```sql
\i procedures.sql
```

### 4. Create Views (if not merged into procedures)
```sql
\i views.sql
```

### 5. Populate Data
```sql
\i data.sql
```
Triggers will auto-update `posts.reaction_count`, `posts.comment_count`, and populate `activity_log` entries.

### 6. Run Sample Queries
```sql
\i queries.sql
```


## Validation Snippets 
You can quickly check volume:
```sql
SELECT 'users', COUNT(*) FROM users;
SELECT 'posts', COUNT(*) FROM posts;
SELECT 'comments', COUNT(*) FROM comments;
SELECT 'reactions', COUNT(*) FROM reactions;
SELECT 'messages', COUNT(*) FROM messages;
SELECT 'activity_log', COUNT(*) FROM activity_log;
```

## Operational Notes

- Re-running `data.sql` will add more rows (ids grow). For a clean reset, TRUNCATE tables (respect FK order) or drop/recreate database.
- `ban_user` procedure updates `regular_users.account_status` to `banned` and logs activity via `log_activity` (action `report_user`).
- `user_engagement_score` is used in views and queries for ranking.
- Upsert-like reaction changes can be done manually (current design counts only insert/delete events). To change reaction type, delete then re-insert.




