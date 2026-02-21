# 🔍 Diagnostic Steps for Push Notification Issue

## Current Status
✅ Edge Function is being called (200 response)  
❓ Need to see what it's actually doing

## Step 1: View Edge Function Console Logs

**In Supabase Dashboard:**
1. Go to **Edge Functions** (left sidebar)
2. Click on **send-notification**
3. Click the **Logs** tab
4. Look for the most recent execution (should match timestamp `1767005158586000`)

**What to look for:**
```
📩 Edge Function invoked at [timestamp]
📦 Raw request body: {...}
🔍 Detecting payload type...
✅ Detected webhook payload from notifications table
   User ID: [user-id]
📱 Found X FCM token(s)  OR  ⚠️ No FCM tokens found
📤 Final response: {...}
```

**If you see "⚠️ No FCM tokens found":**
→ The recipient user doesn't have an FCM token saved. They need to open the app.

## Step 2: Check Webhook Response Body

**In Supabase Dashboard:**
1. Go to **Database** → **Webhooks**
2. Click on your webhook
3. Look for **Logs** or **History** tab
4. Find the most recent execution
5. Click to expand and see the **Response Body**

The response should look like:
```json
{
  "success": true,
  "sent": 1,
  "total": 1,
  "payload": {
    "userId": "...",
    "title": "...",
    "body": "..."
  },
  "diagnostic": "1 notification(s) sent successfully"
}
```

OR if no tokens:
```json
{
  "success": true,
  "message": "No devices registered",
  "diagnostic": "No FCM tokens found in database..."
}
```

## Step 3: Verify Recipient Has FCM Token

**Run this SQL in Supabase SQL Editor:**

```sql
-- Replace with the actual recipient user ID
-- (The user who should receive the notification when you send a message)

SELECT 
  user_id,
  LEFT(token, 20) || '...' as token_preview,
  device_type,
  updated_at
FROM fcm_tokens 
WHERE user_id = 'RECIPIENT_USER_ID_HERE';
```

**If no rows returned:**
- The recipient needs to:
  1. Open the Flutter app
  2. Grant notification permissions when prompted
  3. The app will automatically save the FCM token

**To find the recipient user ID:**
- When you send a message, check which user should receive it
- Or check the `notifications` table to see recent `user_id` values

## Step 4: Check FCM Server Key

**In Supabase Dashboard:**
1. Go to **Project Settings** (gear icon)
2. Click **Edge Functions**
3. Scroll to **Environment Variables**
4. Verify `FCM_SERVER_KEY` is set

**If missing:**
1. Go to **Firebase Console** → Your Project
2. **Project Settings** → **Cloud Messaging** tab
3. Copy the **Server key** (Legacy API)
4. Paste it in Supabase as `FCM_SERVER_KEY`

## Step 5: Test Directly

**Option A: Test via SQL (triggers webhook)**
```sql
-- Insert a test notification
-- Replace RECIPIENT_USER_ID with actual user ID

INSERT INTO notifications (user_id, title, body, type, sub_type, related_id, data)
VALUES (
  'RECIPIENT_USER_ID',
  'Test Notification',
  'This is a test',
  'message',
  'text',
  'test-conversation-id',
  '{"action": "open_chat", "conversationId": "test-conv"}'::jsonb
);
```

Then immediately check:
- Edge Function logs
- Webhook response

**Option B: Test via HTTP (bypasses webhook)**
```bash
# In PowerShell or Terminal
# Replace YOUR_ANON_KEY and RECIPIENT_USER_ID

$headers = @{
    "Authorization" = "Bearer YOUR_ANON_KEY"
    "Content-Type" = "application/json"
}

$body = @{
    userId = "RECIPIENT_USER_ID"
    title = "Test Notification"
    body = "Testing push notification"
    type = "message"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://pbkoxrobqltdyoaemgez.supabase.co/functions/v1/send-notification" -Method Post -Headers $headers -Body $body
```

## Step 6: Most Common Issue

**"No FCM tokens found"** - This is the #1 reason push notifications don't work.

**Solution:**
1. The recipient user must open the app
2. Grant notification permissions
3. The token is saved automatically

**To verify token was saved:**
```sql
SELECT * FROM fcm_tokens ORDER BY updated_at DESC LIMIT 5;
```

## Quick Checklist

- [ ] Edge Function logs show execution
- [ ] Response body shows diagnostic message
- [ ] Recipient user has FCM token in `fcm_tokens` table
- [ ] `FCM_SERVER_KEY` environment variable is set
- [ ] Webhook is enabled and configured correctly

## What to Share

If still not working, share:
1. **Edge Function Logs** - Copy the console.log output
2. **Response Body** - From webhook logs or direct test
3. **FCM Token Query Result** - Does recipient have a token?
4. **FCM_SERVER_KEY Status** - Is it set?




