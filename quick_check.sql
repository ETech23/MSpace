-- ============================================
-- Quick Diagnostic Check
-- Run this to see everything at once
-- ============================================

-- 1. Check recent notifications (what was created)
SELECT 
  id,
  user_id as recipient_id,
  title,
  body,
  type,
  created_at,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM fcm_tokens ft WHERE ft.user_id = notifications.user_id
    ) THEN '✅ Has Token'
    ELSE '❌ No Token'
  END as token_status
FROM notifications 
ORDER BY created_at DESC 
LIMIT 5;

-- 2. Check who has FCM tokens
SELECT 
  user_id,
  LEFT(token, 25) || '...' as token_preview,
  device_type,
  updated_at
FROM fcm_tokens 
ORDER BY updated_at DESC;

-- 3. Check recent booking (to see who should receive notification)
SELECT 
  b.id as booking_id,
  b.customer_id,
  b.artisan_id,
  b.status,
  b.created_at,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM fcm_tokens ft WHERE ft.user_id = b.artisan_id
    ) THEN '✅ Artisan has token'
    ELSE '❌ Artisan needs to open app'
  END as artisan_token_status,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM fcm_tokens ft WHERE ft.user_id = b.customer_id
    ) THEN '✅ Customer has token'
    ELSE '❌ Customer needs to open app'
  END as customer_token_status
FROM bookings b
ORDER BY b.created_at DESC
LIMIT 3;

-- 4. Check your specific booking
SELECT 
  b.id,
  b.customer_id,
  b.artisan_id,
  b.status,
  u1.name as customer_name,
  u2.name as artisan_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM fcm_tokens WHERE user_id = b.artisan_id)
    THEN '✅ Artisan can receive notifications'
    ELSE '❌ Artisan needs to open app to receive notifications'
  END as notification_status
FROM bookings b
JOIN users u1 ON u1.id = b.customer_id
JOIN users u2 ON u2.id = b.artisan_id
WHERE b.id = '8bd124f7-f684-4118-a66a-137f1eb95936';  -- Your booking ID




