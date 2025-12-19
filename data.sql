
-- 200 users
INSERT INTO users (username, email, birth_date, gender, profile_visibility, bio, last_login, profile_picture, password_hash)
SELECT
    'user' || gs AS username,
    'user' || gs || '@example.com' AS email,
    date '1980-01-01' + (random() * 8000)::INT * interval '1 day' AS birth_date,
    (ARRAY['M','F'])[1 + (random()*1)::INT] AS gender,
    (ARRAY['public','private'])[1 + (random()*1)::INT] AS profile_visibility,
    'Bio for user ' || gs,
    now() - (random()*30)::INT * interval '1 day' AS last_login,
    NULL,
    repeat('x', 60 + (random()*20)::INT)
FROM generate_series(1,200) gs;

-- Assign ~20 admins (random subset) and remaining as regular users
INSERT INTO admin_users(user_id, permissions, admin_level, managed_groups)
SELECT id, 'all', (random()*4)::INT + 1, 0
FROM users
WHERE id IN (
    SELECT id FROM users ORDER BY random() LIMIT 20
);

INSERT INTO regular_users(user_id, subscription_type, account_status)
SELECT id,
       (ARRAY['basic','plus','premium'])[1 + (random()*2)::INT],
       'active'
FROM users u
WHERE NOT EXISTS (SELECT 1 FROM admin_users a WHERE a.user_id = u.id);

-- ===============
-- FOLLOWERS (relationship requests)
-- Aim for ~400 follower relationships
INSERT INTO followers(follower_id, followed_id, follow_status, requested_at, responded_at)
SELECT f.id, t.id,
       (ARRAY['pending','accepted','blocked','declined'])[1 + (random()*3)::INT],
       now() - (random()*15)::INT * interval '1 day',
       CASE WHEN random() < 0.7 THEN now() - (random()*10)::INT * interval '1 day' END
FROM (SELECT id FROM users ORDER BY random() LIMIT 120) f
JOIN (SELECT id FROM users ORDER BY random() LIMIT 120) t
  ON f.id <> t.id
LIMIT 400;

-- ===============
-- GROUPS (~25 groups) & MEMBERS (~300 memberships)
INSERT INTO groups(admin_user_id, group_name, group_description, privacy_level, group_type, created_by)
SELECT u.id,
       'group_' || u.id,
       'Description for group ' || u.id,
       (ARRAY['public','private'])[1 + (random()*1)::INT],
       (ARRAY['general','tech','music','sports','gaming'])[1 + (random()*4)::INT],
       u.id
FROM (SELECT id FROM users ORDER BY random() LIMIT 25) u;

INSERT INTO group_members(group_id, user_id, group_member_role, joined_at)
SELECT g.id, u.id,
       (ARRAY['member','moderator','admin'])[1 + (random()*2)::INT],
       now() - (random()*20)::INT * interval '1 day'
FROM groups g
JOIN (SELECT id FROM users ORDER BY random() LIMIT 200) u ON TRUE
WHERE random() < 0.6; -- probabilistic membership

-- ===============
-- CHATS (~40) & PARTICIPANTS & MESSAGES (~600 messages)
-- Ensure group chats (is_group_chat = true) always have a non-null name to satisfy constraint group_name_required
WITH gen AS (
  SELECT gs, (random() < 0.3) AS is_group
  FROM generate_series(1,40) gs
)
INSERT INTO chats(is_group_chat, name, created_by)
SELECT is_group,
     CASE WHEN is_group THEN 'chat_group_' || gs ELSE NULL END,
     (SELECT id FROM users ORDER BY random() LIMIT 1)
FROM gen;

INSERT INTO chat_participants(chat_id, user_id, role)
SELECT c.id, u.id, (ARRAY['member','admin','owner'])[1 + (random()*2)::INT]
FROM chats c
JOIN (SELECT id FROM users ORDER BY random() LIMIT 150) u ON TRUE
WHERE random() < 0.4; -- subset of users per chat

-- Messages
INSERT INTO messages(sender_id, receiver_id, chat_id, content, read_date, sent_date)
SELECT u.id AS sender_id,
     -- For direct (non-group) chats pick a different participant's user_id; chat_participants has no generic id column
     CASE WHEN c.is_group_chat THEN NULL ELSE (
       SELECT cp2.user_id
       FROM chat_participants cp2
       WHERE cp2.chat_id = c.id AND cp2.user_id <> u.id
       ORDER BY random() LIMIT 1
     ) END AS receiver_id,
       c.id,
       'Message ' || gs || ' in chat ' || c.id,
       CASE WHEN random() < 0.7 THEN now() - (random()*5)::INT * interval '1 day' END,
       now() - (random()*15)::INT * interval '1 day'
FROM chats c
JOIN chat_participants cp ON cp.chat_id = c.id
JOIN users u ON u.id = cp.user_id
JOIN generate_series(1,15) gs ON TRUE -- ~15 messages per participant subset
WHERE random() < 0.3; -- limit density

-- ===============
-- POSTS (~450) & REACTIONS (~500) & COMMENTS (~320)
INSERT INTO posts(user_id, content, media_url, visibility)
SELECT u.id,
       'Post content #' || gs || ' by user ' || u.id,
       CASE WHEN random() < 0.2 THEN 'https://cdn.example.com/media/' || gs || '.jpg' END,
       (ARRAY['public','friends','private'])[1 + (random()*2)::INT]
FROM (SELECT id FROM users ORDER BY random() LIMIT 150) u
JOIN generate_series(1,3) gs ON TRUE; -- 3 posts each ~450

-- Reactions
INSERT INTO reactions(post_id, user_id, reaction_type)
SELECT p.id, u.id, (ARRAY['like','love','laugh','shocked','sad','angry'])[1 + (random()*5)::INT]
FROM posts p
JOIN (SELECT id FROM users ORDER BY random() LIMIT 160) u ON TRUE
WHERE random() < 0.25; -- probability filter

-- Comments
INSERT INTO comments(post_id, user_id, parent_comment_id, content)
SELECT p.id, u.id,
       CASE WHEN random() < 0.15 THEN (SELECT c.id FROM comments c WHERE c.post_id = p.id ORDER BY random() LIMIT 1) END,
       'Comment on post ' || p.id || ' by user ' || u.id
FROM posts p
JOIN (SELECT id FROM users ORDER BY random() LIMIT 140) u ON TRUE
WHERE random() < 0.18; -- probability filter

-- After inserts, trigger functions recalc reaction/comment counts automatically.

-- ===============
-- Sanity summary queries (optional; comment out if not desired during population)
-- SELECT 'users', COUNT(*) FROM users;
-- SELECT 'posts', COUNT(*) FROM posts;
-- SELECT 'comments', COUNT(*) FROM comments;
-- SELECT 'reactions', COUNT(*) FROM reactions;
-- SELECT 'messages', COUNT(*) FROM messages;
-- SELECT 'groups', COUNT(*) FROM groups;
-- SELECT 'group_members', COUNT(*) FROM group_members;
-- SELECT 'followers', COUNT(*) FROM followers;
-- Expected total rows across all tables > 1000.

-- End data.sql
