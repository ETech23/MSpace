-- ============================================
-- Push Notification Diagnostic Queries
-- Run these in Supabase SQL Editor
-- ============================================

-- 1. Check recent notifications (to see what's being created)
SELECT 
  id,
  user_id,
  title,
  body,
  type,
  created_at
FROM notifications 
WHERE type = 'message'
ORDER BY created_at DESC 
LIMIT 5;

-- 2. Check if users have FCM tokens saved
SELECT 
  user_id,
  LEFT(token, 20) || '...' as token_preview,
  device_type,
  updated_at,
  CASE 
    WHEN updated_at > NOW() - INTERVAL '7 days' THEN 'Recent'
    ELSE 'Old'
  END as token_age
FROM fcm_tokens 
ORDER BY updated_at DESC;

-- 3. Check specific user's FCM token (replace USER_ID)
-- SELECT * FROM fcm_tokens WHERE user_id = 'USER_ID_HERE';

-- 4. Count tokens per user
SELECT 
  user_id,
  COUNT(*) as token_count,
  MAX(updated_at) as last_updated
FROM fcm_tokens
GROUP BY user_id
ORDER BY last_updated DESC;

-- 5. Check recent message sends (to see who should receive notifications)
SELECT 
  m.id,
  m.conversation_id,
  m.sender_id,
  m.message_text,
  m.created_at,
  c.participant1_id,
  c.participant2_id,
  CASE 
    WHEN c.participant1_id = m.sender_id THEN c.participant2_id
    ELSE c.participant1_id
  END as recipient_id
FROM messages m
JOIN conversations c ON c.id = m.conversation_id
ORDER BY m.created_at DESC
LIMIT 5;

-- 6. Check if recipient has FCM token (for recent messages)
SELECT 
  m.id as message_id,
  CASE 
    WHEN c.participant1_id = m.sender_id THEN c.participant2_id
    ELSE c.participant1_id
  END as recipient_id,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM fcm_tokens ft 
      WHERE ft.user_id = CASE 
        WHEN c.participant1_id = m.sender_id THEN c.participant2_id
        ELSE c.participant1_id
      END
    ) THEN 'Has Token ✓'
    ELSE 'No Token ✗'
  END as token_status
FROM messages m
JOIN conversations c ON c.id = m.conversation_id
ORDER BY m.created_at DESC
LIMIT 5;

