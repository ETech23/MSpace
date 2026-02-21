# Webhook Push Notification Debugging Guide

## Issue: Push notifications not appearing when sending messages

### Step 1: Verify Edge Function is Deployed

```bash
# Check if function is deployed
supabase functions list

# If not deployed, deploy it:
supabase functions deploy send-notification
```

### Step 2: Check Webhook Configuration in Supabase Dashboard

1. Go to **Supabase Dashboard** → **Database** → **Webhooks**
2. Find your webhook for the `notifications` table
3. Verify:
   - ✅ **Table**: `notifications`
   - ✅ **Events**: `INSERT` (checked)
   - ✅ **Type**: `Supabase Edge Function`
   - ✅ **Function**: `send-notification`
   - ✅ **HTTP Method**: `POST`
   - ✅ **Status**: Enabled/Active

### Step 3: Verify Environment Variables

The Edge Function needs these environment variables:

```bash
# Set environment variables (if using Supabase CLI)
supabase secrets set FCM_SERVER_KEY=your_fcm_server_key_here

# Or in Supabase Dashboard:
# Project Settings → Edge Functions → Environment Variables
```

Required variables:
- `SUPABASE_URL` (auto-set)
- `SUPABASE_SERVICE_ROLE_KEY` (auto-set)
- `FCM_SERVER_KEY` (you must set this)

### Step 4: Check Edge Function Logs

1. Go to **Supabase Dashboard** → **Edge Functions** → **send-notification**
2. Click **Logs** tab
3. Send a test message and watch for:
   - `📩 Edge Function invoked` - confirms webhook triggered
   - `📦 Raw request body` - shows the payload received
   - `✅ Detected webhook payload` - confirms payload parsing
   - `📱 Found X FCM token(s)` - confirms tokens found
   - `✅ FCM Success!` - confirms notification sent

### Step 5: Test the Edge Function Directly

You can test the Edge Function directly to verify it works:

```bash
# Get your Supabase project URL and anon key
# Then call the function:

curl -X POST \
  'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notification' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "USER_ID_TO_SEND_TO",
    "title": "Test Notification",
    "body": "This is a test",
    "type": "message"
  }'
```

### Step 6: Verify FCM Token is Saved

Check if the recipient user has an FCM token saved:

```sql
-- Run in Supabase SQL Editor
SELECT * FROM fcm_tokens WHERE user_id = 'RECIPIENT_USER_ID';
```

If no tokens exist, the user needs to:
1. Open the app
2. Grant notification permissions
3. The app will automatically save the token

### Step 7: Common Issues & Solutions

#### Issue: "No FCM tokens found for user"
- **Solution**: User needs to open the app and grant notification permissions
- The token is saved automatically when `FCMNotificationService.initialize()` runs

#### Issue: "Missing FCM_SERVER_KEY"
- **Solution**: Set the environment variable in Supabase Dashboard
- Get your FCM Server Key from Firebase Console → Project Settings → Cloud Messaging → Server key

#### Issue: Webhook not triggering
- **Solution**: 
  1. Verify webhook is enabled
  2. Check webhook logs in Supabase Dashboard
  3. Try recreating the webhook

#### Issue: Edge Function returns 500 error
- **Solution**: Check Edge Function logs for detailed error messages
- Common causes: Missing env vars, invalid FCM key, database connection issues

### Step 8: Manual Test - Insert Notification Directly

Test by inserting a notification directly into the database:

```sql
-- Insert test notification
INSERT INTO notifications (user_id, title, body, type, sub_type, related_id, data)
VALUES (
  'RECIPIENT_USER_ID',
  'Test Message',
  'This is a test notification',
  'message',
  'text',
  'CONVERSATION_ID',
  '{"action": "open_chat", "conversationId": "CONVERSATION_ID"}'::jsonb
);
```

This should trigger the webhook and send a push notification.

### Step 9: Verify Message Insertion Creates Notification

When you send a message, check if a notification row is created:

```sql
-- Check recent notifications
SELECT * FROM notifications 
WHERE type = 'message' 
ORDER BY created_at DESC 
LIMIT 5;
```

If notifications are being created but push notifications aren't sent, the webhook might not be configured correctly.

## Quick Checklist

- [ ] Edge Function is deployed (`supabase functions deploy send-notification`)
- [ ] Webhook is configured and enabled in Supabase Dashboard
- [ ] `FCM_SERVER_KEY` environment variable is set
- [ ] Recipient user has FCM token saved in `fcm_tokens` table
- [ ] Edge Function logs show webhook being triggered
- [ ] No errors in Edge Function logs
- [ ] FCM Server Key is valid (from Firebase Console)


