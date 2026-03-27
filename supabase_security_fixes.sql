-- ═══════════════════════════════════════════════════════════════
-- SAFESPACE SECURITY FIXES - Run in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. RLS for connections table ───
-- Without this, any authenticated user can read/modify/delete ANY connection

ALTER TABLE connections ENABLE ROW LEVEL SECURITY;

-- Users can read connections they're part of
CREATE POLICY "Users can read own connections" ON connections
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Users can send connection requests (insert as sender)
CREATE POLICY "Users can send connection requests" ON connections
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Only receiver can accept (update status)
CREATE POLICY "Receiver can update connection" ON connections
  FOR UPDATE USING (auth.uid() = receiver_id);

-- Users can delete their own connections
CREATE POLICY "Users can delete own connections" ON connections
  FOR DELETE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);


-- ─── 2. RLS for thoughts delete (owner only) ───
-- Without this, any user can delete any thought via API

CREATE POLICY "Users can delete own thoughts" ON thoughts
  FOR DELETE USING (auth.uid() = user_id);


-- ─── 3. RLS for thoughts_comments delete (owner only) ───

CREATE POLICY "Users can delete own comments" ON thought_comments
  FOR DELETE USING (auth.uid() = user_id);


-- ─── 4. Atomic rating RPC (fixes race condition) ───
-- The Flutter app reads rating + total_talks, calculates new average, writes back.
-- Two users rating simultaneously = one rating is lost.
-- This RPC does the calculation atomically on the server.

CREATE OR REPLACE FUNCTION submit_rating(
  target_id UUID,
  stars INT,
  tag TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  -- Validate input
  IF stars < 1 OR stars > 5 THEN
    RAISE EXCEPTION 'Stars must be between 1 and 5';
  END IF;

  -- Prevent self-rating
  IF target_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot rate yourself';
  END IF;

  -- Insert rating record
  INSERT INTO user_ratings (rater_id, target_id, stars, tag_selected)
  VALUES (auth.uid(), target_id, stars, tag);

  -- Atomically update profile stats (no race condition)
  UPDATE profiles SET
    rating = CASE
      WHEN total_talks = 0 THEN stars::FLOAT
      ELSE (rating * total_talks + stars) / (total_talks + 1)
    END,
    total_talks = total_talks + 1
  WHERE id = target_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 5. Atomic talks count increment (fixes race condition) ───

CREATE OR REPLACE FUNCTION increment_talks_count()
RETURNS VOID AS $$
BEGIN
  UPDATE profiles SET
    total_talks = total_talks + 1
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 6. Account deletion RPC (GDPR compliance) ───
-- Cascades delete across all user data

CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS VOID AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete user's content
  DELETE FROM thought_comments WHERE user_id = uid;
  DELETE FROM thoughts WHERE user_id = uid;
  DELETE FROM messages WHERE sender_id = uid;
  DELETE FROM user_ratings WHERE rater_id = uid;
  DELETE FROM connections WHERE sender_id = uid OR receiver_id = uid;
  DELETE FROM profiles WHERE id = uid;

  -- Note: auth.users deletion requires admin/service_role key
  -- Handle in Edge Function with service_role
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 7. Rate limiting on thoughts (server-side) ───
-- Prevents bypassing client-side rate limit

CREATE OR REPLACE FUNCTION check_thought_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
  thought_count INT;
BEGIN
  SELECT COUNT(*) INTO thought_count
  FROM thoughts
  WHERE user_id = NEW.user_id
    AND created_at > NOW() - INTERVAL '24 hours';

  IF thought_count >= 5 THEN
    RAISE EXCEPTION 'Rate limit: Max 5 thoughts per 24 hours';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER thought_rate_limit_trigger
  BEFORE INSERT ON thoughts
  FOR EACH ROW
  EXECUTE FUNCTION check_thought_rate_limit();


-- ─── 8. Comment length validation (server-side) ───

CREATE OR REPLACE FUNCTION validate_comment_length()
RETURNS TRIGGER AS $$
BEGIN
  IF length(NEW.content) > 500 THEN
    RAISE EXCEPTION 'Comment too long. Max 500 characters.';
  END IF;
  IF length(NEW.content) = 0 THEN
    RAISE EXCEPTION 'Comment cannot be empty.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER comment_length_trigger
  BEFORE INSERT ON thought_comments
  FOR EACH ROW
  EXECUTE FUNCTION validate_comment_length();


-- ═══════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES (run after applying fixes)
-- ═══════════════════════════════════════════════════════════════

-- Check RLS is enabled on connections
-- SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'connections';

-- Check policies exist
-- SELECT * FROM pg_policies WHERE tablename = 'connections';

-- Test rating RPC
-- SELECT submit_rating('some-uuid-here', 5, 'Empathetic');
