-- Social Network Database
-- Authors: Andreia Martins fc45147
--          Rimsha Sohail fc66789
-- =====================================
-- views.sql (supplemental) --
-- Define common reporting views (>=4)

-- 1) User Post Stats: counts of posts, reactions made, comments made
CREATE OR REPLACE VIEW vw_user_post_stats AS
SELECT u.id AS user_id, u.username,
       COUNT(DISTINCT p.id) AS post_count,
       COUNT(DISTINCT r.post_id) AS reacted_posts,
       COUNT(r.*) AS reaction_total,
       COUNT(c.*) AS comment_total,
       user_engagement_score(u.id) AS engagement_score
FROM users u
LEFT JOIN posts p ON p.user_id = u.id
LEFT JOIN reactions r ON r.user_id = u.id
LEFT JOIN comments c ON c.user_id = u.id
GROUP BY u.id, u.username;

-- using the command line to check weather the command works or not 
SELECT * from vw_user_post_stats ;

-- 2) Group Member Counts
CREATE OR REPLACE VIEW vw_group_member_counts AS
SELECT g.id AS group_id, g.group_name,
       COUNT(DISTINCT gm.user_id) AS member_count,
       COUNT(*) FILTER (WHERE gm.group_member_role = 'admin') AS admin_count,
       COUNT(*) FILTER (WHERE gm.group_member_role = 'moderator') AS moderator_count
FROM groups g
LEFT JOIN group_members gm ON gm.group_id = g.id
GROUP BY g.id, g.group_name;

-- using the command line to check weather the command works or not 
SELECT * from vw_group_member_counts ;


-- 3) Top Active Users (by engagement score) limited to top 50
CREATE OR REPLACE VIEW vw_top_active_users AS
SELECT * FROM vw_user_post_stats
ORDER BY engagement_score DESC
LIMIT 50;

-- using the command line to check weather the command works or not 
SELECT * from vw_top_active_users ;


-- 4) Post Engagement Summary
CREATE OR REPLACE VIEW vw_post_engagement AS
SELECT p.id AS post_id, p.user_id, u.username,
       p.reaction_count, p.comment_count,
       (p.reaction_count + p.comment_count) AS total_interactions,
       p.created_at
FROM posts p
JOIN users u ON u.id = p.user_id;


-- using the command line to check weather the command works or not 
SELECT * from vw_post_engagement ;

-- 5) Chat Activity (extra)
CREATE OR REPLACE VIEW vw_chat_activity AS
SELECT c.id AS chat_id, c.is_group_chat, c.name, c.created_at, c.last_message_at,
       COUNT(DISTINCT m.id) AS message_count,
       COUNT(DISTINCT cp.user_id) AS participant_count
FROM chats c
LEFT JOIN messages m ON m.chat_id = c.id
LEFT JOIN chat_participants cp ON cp.chat_id = c.id
GROUP BY c.id, c.is_group_chat, c.name, c.created_at, c.last_message_at;


-- using the command line to check weather the command works or not 
SELECT * from vw_chat_activity;
-- End views.sql
