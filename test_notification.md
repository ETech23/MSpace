# Test Notification Function

## Step 1: Check the Actual Response Body

The Edge Function is returning 200, but we need to see what it's actually saying. 

### Option A: Check Edge Function Logs (Best)
1. Go to **Supabase Dashboard** → **Edge Functions** → **send-notification**
2. Click **Logs** tab
3. Look for the most recent execution
4. You should see logs like:
   - `📩 Edge Function invoked`
   - `📦 Raw request body`
   - `🔍 Detecting payload type`
   - `📱 Found X FCM token(s)` OR `⚠️ No FCM tokens found`

### Option B: Check Webhook Logs
1. Go to **Supabase Dashboard** → **Database** → **Webhooks**
2. Click on your webhook
3. Check the **Logs** or **History** tab
4. Look at the response body

### Option C: Test Directly with curl

Replace `YOUR_PROJECT_REF`, `YOUR_ANON_KEY`, and `RECIPIENT_USER_ID`:

```bash
curl -X POST \
  'https://pbkoxrobqltdyoaemgez.supabase.co/functions/v1/send-notification' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "RECIPIENT_USER_ID",
    "title": "Test Notification",
    "body": "Testing push notification",
    "type": "message"
  }'
```

The response will tell you:
- If tokens were found
- How many were sent
- Any errors

## Step 2: Verify Recipient Has FCM Token

### Local quick test (dev)
If you are running the Edge Function locally (via `supabase functions serve`), you can use the included test script to send a payload with numeric fields that previously caused FCM TYPE_STRING errors:

```bash
# from repository root
cd supabase/functions/send-notification
./test-send.sh
```

This script posts to `http://localhost:9999` and prints the response. Look for `📋 safeData:` and `📥 FCM Response (200)` in the function logs.



Run this SQL query in Supabase SQL Editor:

```sql
-- Check if recipient has FCM token
SELECT 
  user_id,
  token,
  device_type,
  updated_at
FROM fcm_tokens 
WHERE user_id = 'RECIPIENT_USER_ID';
```

**If no rows returned:**
- The recipient needs to open the app
- Grant notification permissions
- The token will be saved automatically

## Step 3: Check FCM Server Key

1. Go to **Supabase Dashboard** → **Project Settings** → **Edge Functions** → **Environment Variables**
2. Verify `FCM_SERVER_KEY` is set
3. Get it from: **Firebase Console** → **Project Settings** → **Cloud Messaging** → **Server key**

## Step 4: Test with Direct Database Insert

Insert a notification directly to trigger the webhook:

```sql
-- Replace with actual user ID
INSERT INTO notifications (user_id, title, body, type, sub_type, related_id, data)
VALUES (
  'RECIPIENT_USER_ID',  -- The user who should receive the notification
  'Test Message',
  'Testing push notification',
  'message',
  'text',
  'test-conversation-id',
  '{"action": "open_chat", "conversationId": "test-conv"}'::jsonb
);
```

Then immediately check:
1. Edge Function logs
2. Webhook logs
3. Response body

## Common Issues

### Issue: "No devices registered" in response
**Solution:** Recipient user needs to:
1. Open the app on their device
2. Grant notification permissions
3. Token will be saved automatically

### Issue: Function returns 200 but no notification appears
**Possible causes:**
1. FCM Server Key is invalid or missing
2. Token is invalid (check FCM response in logs)
3. Device is not connected to internet
4. App notification channels not set up (Android)

### Issue: Function not being called
**Solution:**
1. Verify webhook is enabled
2. Check webhook configuration
3. Verify Edge Function is deployed: `supabase functions deploy send-notification`


