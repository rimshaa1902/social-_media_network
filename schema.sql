-- Social Network Database Schema
-- Authors: Andreia Martins fc45147
--          Rimsha Sohail fc66789
-- =====================================
-- schema.sql
-- Defines tables, constraints, and indexes
-- =====================================

-- =====================================
-- USERS 
-- =====================================
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE CHECK (username ~ '^[A-Za-z0-9_]+$'),
    email VARCHAR(255) NOT NULL UNIQUE CHECK (email LIKE '%@%.%'),
    birth_date DATE CHECK (birth_date <= '2012-12-31'), 
    gender CHAR(1) CHECK (gender IN ('M', 'F')),
    profile_visibility VARCHAR(255) NOT NULL DEFAULT 'public' CHECK (profile_visibility IN ('public', 'private')),
    bio TEXT,
    last_login TIMESTAMPTZ,
    profile_picture VARCHAR(255),
    password_hash TEXT NOT NULL CHECK (length(password_hash) > 30),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================
-- HERANCA (Admin e Regular)

-- Implementcao de heranca 1:1 (subtipos):
-- Cada utilizador na tabela "users" pode ter uma entrada adicional em
-- "admin_users" (se for administrador) ou "regular_users" (se for utilizador normal).
-- Esta abordagem garante integridade referencial e mantem os atributos
-- especificos de cada tipo de utilizador isolados.
-- =====================================
-- =====================================

CREATE TABLE admin_users (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    permissions TEXT NOT NULL DEFAULT 'limited',
    admin_level INT CHECK (admin_level BETWEEN 1 AND 5),
    managed_groups INT
);

CREATE TABLE regular_users (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    subscription_type VARCHAR(255) NOT NULL DEFAULT 'basic',
    account_status VARCHAR(255) NOT NULL DEFAULT 'active'
        CHECK (account_status IN ('active','suspended','deleted','pending','banned'))
);


-- =====================================
-- POSTS & COMMENTS & REACTIONS
-- =====================================
CREATE TABLE posts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (length(trim(content)) > 0),
    media_url TEXT,
    reaction_count INT NOT NULL DEFAULT 0 CHECK (reaction_count >= 0),
    comment_count INT NOT NULL DEFAULT 0 CHECK (comment_count >= 0),
    visibility VARCHAR(255) NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','friends','private')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE comments (
    id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_comment_id BIGINT REFERENCES comments(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE reactions (
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reaction_type VARCHAR(20) NOT NULL CHECK (reaction_type IN ('like','love','laugh','shocked','sad','angry')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id, reaction_type)
);

-- =====================================
-- FOLLOWERS
-- =====================================
CREATE TABLE followers (
    follower_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followed_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    follow_status VARCHAR(15) NOT NULL DEFAULT 'pending' CHECK (follow_status IN ('pending','accepted','blocked','declined')),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    responded_at TIMESTAMPTZ,
    PRIMARY KEY (follower_id, followed_id),
    CONSTRAINT no_self_friend CHECK (follower_id <> followed_id)
);

-- =====================================
-- MESSAGES AND CHATS
-- =====================================

CREATE TABLE chats (
    id BIGSERIAL PRIMARY KEY,
    is_group_chat BOOLEAN NOT NULL DEFAULT false,
    name VARCHAR(100),
    created_by BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_message_at TIMESTAMPTZ, -- updated by trigger when a new message is inserted
    CONSTRAINT group_name_required CHECK (
        (is_group_chat = true AND name IS NOT NULL)
        OR (is_group_chat = false)
    )
);


CREATE TABLE chat_participants (
    chat_id BIGINT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    role VARCHAR(20) NOT NULL DEFAULT 'member'
        CHECK (role IN ('member', 'admin', 'owner')),
    PRIMARY KEY (chat_id, user_id)
);


CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    chat_id BIGINT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    read_date TIMESTAMPTZ,
    sent_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT no_self_message CHECK (sender_id <> receiver_id)
);

-- =====================================
-- GROUPS & MEMBERS
-- =====================================
CREATE TABLE groups (
    id BIGSERIAL PRIMARY KEY,
    admin_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_name VARCHAR(80) NOT NULL UNIQUE,
    group_description TEXT,
    privacy_level VARCHAR(15) NOT NULL DEFAULT 'public' CHECK (privacy_level IN ('public', 'private')),
    group_type VARCHAR(30) NOT NULL DEFAULT 'general',
    created_by BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT group_creator_is_admin CHECK (admin_user_id = created_by)
);

CREATE TABLE group_members (
    group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_member_role VARCHAR(20) NOT NULL DEFAULT 'member' CHECK (group_member_role IN ('member', 'moderator', 'admin')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (group_id, user_id)
);


-- =====================================
-- Activity Log
-- =====================================
CREATE TABLE activity_log (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    action_type VARCHAR(40) NOT NULL CHECK (action_type IN ('login', 'logout', 'create_group', 'join_group','leave_group',
            'send_message', 'delete_message',
            'update_profile', 'create_post', 'react_post', 'report_user'
        )),
    reference_type VARCHAR(30) CHECK (reference_type IN ('group', 'message', 'post', 'user', 'comment', 'reaction','chat')),
    reference_id BIGINT, 
    details TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================
-- INDEXES (Performance / Common Access Paths)
-- =====================================

CREATE INDEX idx_reactions_user ON reactions(user_id);
CREATE INDEX idx_followers_followed_status ON followers(followed_id, follow_status);
CREATE INDEX idx_messages_sender_created_at ON messages(sender_id, sent_date DESC);
CREATE INDEX idx_messages_receiver_sent_date ON messages(receiver_id, sent_date DESC);
CREATE INDEX idx_group_members_user ON group_members(user_id);
CREATE INDEX idx_posts_user_created_at ON posts(user_id, created_at DESC);
CREATE INDEX idx_comments_post_created_at ON comments(post_id, created_at DESC);
CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_reactions_post_id ON reactions(post_id);


-- =====================================
-- FUTURE TRIGGERS & FUNCTIONS (Placeholders)
-- Will be implemented in triggers/triggers.sql & functions/functions.sql
-- Examples:
-- 1) Auto-update post reaction_count and comment_count via AFTER INSERT/DELETE triggers
-- 2) Log user actions (insert into activity_log) using trigger functions
-- 3) Prevent invalid duplicate reactions per user/post
-- 4) Automatically remove group_members when group deleted
-- 5) Maintain chat activity timestamps (last_message_at)
-- =====================================

-- =====================================
-- END OF SCHEMA
-- This script defines all base tables, constraints and indexes 
-- for the Social Network database system.
-- Execute with: psql -d social_network_dev -f schema/schema.sql
-- =====================================

