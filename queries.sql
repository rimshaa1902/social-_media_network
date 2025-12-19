-- queries.sql
-- 20 functional queries (CRUD, analytics, window functions, joins)

-- 1) List newest 20 public posts with author
SELECT p.id, u.username, p.content, p.created_at
FROM posts p JOIN users u ON u.id = p.user_id
WHERE p.visibility = 'public'
ORDER BY p.created_at DESC
LIMIT 20;

-- 2) Get a user's profile and age
SELECT u.*, get_user_age(u.id) AS age_years FROM users u WHERE u.username = 'user1';

-- 3) Update a user's bio
UPDATE users SET bio = 'Updated bio example' WHERE username = 'user2';

-- 4) Delete a reaction (simulate undo like)
-- Pick an existing reaction randomly to delete (safer than hard-coded IDs)
WITH target AS (
  SELECT post_id, user_id, reaction_type
  FROM reactions
  ORDER BY random() LIMIT 1
)
DELETE FROM reactions r
USING target t
WHERE r.post_id = t.post_id AND r.user_id = t.user_id AND r.reaction_type = t.reaction_type;

-- 5) Insert a new post (uses trigger for activity log)
INSERT INTO posts(user_id, content, visibility)
SELECT id, 'Hello network!', 'public'
FROM users
ORDER BY random() LIMIT 1;

-- 6) Complex follower status counts per user
SELECT u.id, u.username,
       COUNT(*) FILTER (WHERE f.follow_status = 'accepted') AS accepted_count,
       COUNT(*) FILTER (WHERE f.follow_status = 'pending') AS pending_count,
       COUNT(*) FILTER (WHERE f.follow_status = 'blocked') AS blocked_count
FROM users u
LEFT JOIN followers f ON f.followed_id = u.id
GROUP BY u.id, u.username
ORDER BY accepted_count DESC;

-- 7) Window rank of users by engagement score
SELECT user_id, username, engagement_score,
       RANK() OVER (ORDER BY engagement_score DESC) AS engagement_rank
FROM vw_user_post_stats
ORDER BY engagement_rank
LIMIT 30;

-- 8) Top 10 most reacted posts
SELECT p.id, u.username, p.reaction_count
FROM posts p JOIN users u ON u.id = p.user_id
ORDER BY p.reaction_count DESC
LIMIT 10;

-- 9) Comments tree for a post (flattened with parent)
SELECT c.id, c.post_id, c.user_id, c.parent_comment_id, c.content, c.created_at
FROM comments c
WHERE c.post_id = 15
ORDER BY c.created_at;

-- 10) Messages in a chat with sender usernames
SELECT m.id, s.username AS sender, m.content, m.sent_date
FROM messages m
JOIN users s ON s.id = m.sender_id
WHERE m.chat_id = 2
ORDER BY m.sent_date DESC
LIMIT 50;

-- 11) Group membership roles summary
SELECT g.group_name, gm.group_member_role, COUNT(*) AS role_count
FROM groups g
JOIN group_members gm ON gm.group_id = g.id
GROUP BY g.group_name, gm.group_member_role
ORDER BY g.group_name;

-- 12) Active chats (with last activity)
SELECT chat_id, is_group_chat, name, last_message_at, message_count, participant_count
FROM vw_chat_activity
ORDER BY last_message_at DESC NULLS LAST
LIMIT 25;

-- 13) Post engagement distribution (bucketed)
SELECT CASE
         WHEN (reaction_count + comment_count) < 5 THEN 'low'
         WHEN (reaction_count + comment_count) BETWEEN 5 AND 15 THEN 'medium'
         ELSE 'high'
       END AS engagement_bucket,
       COUNT(*) AS posts
FROM posts
GROUP BY engagement_bucket
ORDER BY posts DESC;

-- 14) Most followed users (accepted status)
SELECT u.id, u.username, COUNT(*) AS followers
FROM users u
JOIN followers f ON f.followed_id = u.id AND f.follow_status = 'accepted'
GROUP BY u.id, u.username
ORDER BY followers DESC
LIMIT 15;

-- 15) Activity log recent actions
SELECT al.id, al.user_id, u.username, al.action_type, al.reference_type, al.reference_id, al.created_at
FROM activity_log al LEFT JOIN users u ON u.id = al.user_id
ORDER BY al.created_at DESC
LIMIT 40;

-- 16) Average engagement by privacy level
SELECT privacy_level,
       AVG(reaction_count) AS avg_reactions,
       AVG(comment_count) AS avg_comments
FROM posts p
JOIN groups g ON g.admin_user_id = p.user_id -- Example correlation (admin's posts vs group privacy)
GROUP BY privacy_level;

-- 17) Detect potential inactive users (no posts & no messages)
SELECT u.id, u.username
FROM users u
LEFT JOIN posts p ON p.user_id = u.id
LEFT JOIN messages m ON m.sender_id = u.id
WHERE p.id IS NULL AND m.id IS NULL
LIMIT 50;

-- 18) Use user_engagement_score directly
SELECT u.id, u.username, user_engagement_score(u.id) AS score
FROM users u
ORDER BY score DESC
LIMIT 25;

-- 19) Chat with most participants
SELECT chat_id, participant_count
FROM vw_chat_activity
ORDER BY participant_count DESC
LIMIT 1;

-- 20) Followers mutual relationships (friend-like)
SELECT f1.follower_id AS user_a, f1.followed_id AS user_b
FROM followers f1
JOIN followers f2 ON f2.follower_id = f1.followed_id AND f2.followed_id = f1.follower_id
WHERE f1.follow_status = 'accepted' AND f2.follow_status = 'accepted'
LIMIT 30;

-- End queries.sql
