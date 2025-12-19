-- procedures.sql
-- PL/pgSQL stored functions, procedures, and trigger functions + trigger creation
-- Order: utility functions, business procedures, trigger functions, triggers

-- =========================
-- Utility Function: get_user_age
-- =========================
CREATE OR REPLACE FUNCTION get_user_age(p_user_id BIGINT)
RETURNS INT LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_birth DATE;
BEGIN
    SELECT birth_date INTO v_birth FROM users WHERE id = p_user_id;
    IF v_birth IS NULL THEN
        RETURN NULL; -- user missing or birth date unknown
    END IF;
    RETURN date_part('year', age(current_date, v_birth))::INT;
END;$$;

-- =========================
-- Business Procedure: ban_user
-- Sets account_status to 'banned' and logs activity
-- =========================
CREATE OR REPLACE PROCEDURE ban_user(p_user_id BIGINT, p_reason TEXT DEFAULT 'violation')
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE regular_users SET account_status = 'banned' WHERE user_id = p_user_id;
    PERFORM log_activity(p_user_id, 'report_user', 'user', p_user_id, 'Ban reason: ' || coalesce(p_reason,'none')); -- reuse generic logging
END;$$;

-- =========================
-- Logging Helper: log_activity
-- =========================
CREATE OR REPLACE FUNCTION log_activity(p_user_id BIGINT,
                                        p_action_type VARCHAR,
                                        p_reference_type VARCHAR,
                                        p_reference_id BIGINT,
                                        p_details TEXT)
RETURNS VOID LANGUAGE plpgsql VOLATILE AS $$
BEGIN
    INSERT INTO activity_log(user_id, action_type, reference_type, reference_id, details)
    VALUES (p_user_id, p_action_type, p_reference_type, p_reference_id, p_details);
END;$$;

-- =========================
-- Trigger Function: update reaction_count on posts
-- =========================
CREATE OR REPLACE FUNCTION trg_update_post_reaction_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE posts p
    SET reaction_count = (
        SELECT COUNT(*) FROM reactions r WHERE r.post_id = p.id
    )
    WHERE p.id = COALESCE(NEW.post_id, OLD.post_id);
    RETURN NULL; -- AFTER trigger
END;$$;

-- =========================
-- Trigger Function: update comment_count on posts
-- =========================
CREATE OR REPLACE FUNCTION trg_update_post_comment_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE posts p
    SET comment_count = (
        SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id
    )
    WHERE p.id = COALESCE(NEW.post_id, OLD.post_id);
    RETURN NULL;
END;$$;

-- =========================
-- Trigger Function: touch chat last_message_at
-- =========================
CREATE OR REPLACE FUNCTION trg_touch_chat_last_message_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE chats SET last_message_at = NEW.sent_date WHERE id = NEW.chat_id;
    RETURN NEW;
END;$$;

-- =========================
-- Trigger Function: generic activity logger for posts & reactions & messages
-- =========================
CREATE OR REPLACE FUNCTION trg_activity_logger()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_action VARCHAR(40);
    v_ref_type VARCHAR(30);
    v_ref_id BIGINT;
    v_user BIGINT;
BEGIN
    IF TG_TABLE_NAME = 'posts' THEN
        v_action := 'create_post'; v_ref_type := 'post'; v_ref_id := NEW.id; v_user := NEW.user_id;
    ELSIF TG_TABLE_NAME = 'reactions' THEN
        v_action := 'react_post'; v_ref_type := 'reaction'; v_ref_id := NEW.post_id; v_user := NEW.user_id;
    ELSIF TG_TABLE_NAME = 'messages' THEN
        v_action := 'send_message'; v_ref_type := 'message'; v_ref_id := NEW.id; v_user := NEW.sender_id;
    ELSE
        RETURN NEW; -- unsupported
    END IF;
    PERFORM log_activity(v_user, v_action, v_ref_type, v_ref_id, 'auto');
    RETURN NEW;
END;$$;

-- =========================
-- TRIGGERS CREATION
-- =========================
-- Silent conditional trigger drops (avoids NOTICE spam on first run)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT * FROM (VALUES
            ('trg_reaction_count_insert','reactions'),
            ('trg_reaction_count_delete','reactions'),
            ('trg_comment_count_insert','comments'),
            ('trg_comment_count_delete','comments'),
            ('trg_chat_last_message','messages'),
            ('trg_activity_posts','posts'),
            ('trg_activity_reactions','reactions'),
            ('trg_activity_messages','messages')
        ) AS v(name, tbl)
    ) LOOP
        IF EXISTS (
            SELECT 1 FROM pg_trigger tg
            JOIN pg_class c ON c.oid = tg.tgrelid
            WHERE tg.tgname = r.name AND c.relname = r.tbl
        ) THEN
            EXECUTE format('DROP TRIGGER %I ON %I;', r.name, r.tbl);
        END IF;
    END LOOP;
END$$;

-- Recreate triggers
CREATE TRIGGER trg_reaction_count_insert
AFTER INSERT ON reactions
FOR EACH ROW EXECUTE FUNCTION trg_update_post_reaction_count();

CREATE TRIGGER trg_reaction_count_delete
AFTER DELETE ON reactions
FOR EACH ROW EXECUTE FUNCTION trg_update_post_reaction_count();

CREATE TRIGGER trg_comment_count_insert
AFTER INSERT ON comments
FOR EACH ROW EXECUTE FUNCTION trg_update_post_comment_count();

CREATE TRIGGER trg_comment_count_delete
AFTER DELETE ON comments
FOR EACH ROW EXECUTE FUNCTION trg_update_post_comment_count();

CREATE TRIGGER trg_chat_last_message
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION trg_touch_chat_last_message_at();

CREATE TRIGGER trg_activity_posts
AFTER INSERT ON posts
FOR EACH ROW EXECUTE FUNCTION trg_activity_logger();

CREATE TRIGGER trg_activity_reactions
AFTER INSERT ON reactions
FOR EACH ROW EXECUTE FUNCTION trg_activity_logger();

CREATE TRIGGER trg_activity_messages
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION trg_activity_logger();

-- =========================
-- Additional Sample Function: user_engagement_score
-- Returns (posts + reactions + comments)
-- =========================
CREATE OR REPLACE FUNCTION user_engagement_score(p_user_id BIGINT)
RETURNS INT LANGUAGE sql STABLE AS $$
    SELECT (
        (SELECT COUNT(*) FROM posts WHERE user_id = p_user_id) +
        (SELECT COUNT(*) FROM reactions WHERE user_id = p_user_id) +
        (SELECT COUNT(*) FROM comments WHERE user_id = p_user_id)
    )::INT;
$$;

-- End of procedures.sql
