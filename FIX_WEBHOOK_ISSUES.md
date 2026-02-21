# 🔧 Fix Webhook Issues

## Issues Found in Logs

1. ✅ **Edge Function `send-notification` is working** (200 response)
2. ❌ **404 Error for `on-message-created`** - Old webhook needs to be removed
3. ⚠️ **Realtime warning** - Not critical but should be fixed

## Step 1: Remove Old Webhook (404 Error)

**In Supabase Dashboard:**
1. Go to **Database** → **Webhooks**
2. Look for a webhook pointing to `on-message-created`
3. **Delete it** (it's causing 404 errors)

**Why:** This webhook is trying to call a function that doesn't exist. It's not needed since we're using `send-notification` for the `notifications` table.

## Step 2: Check Edge Function Response Body

The Edge Function is returning 200, but we need to see **what it's actually saying**.

**Option A: View in Dashboard (Best)**
1. Go to **Edge Functions** → **send-notification**
2. Click **Logs** tab
3. Find the most recent execution (timestamp: `1767159227252000`)
4. Look for the console.log output:
   - `📦 Raw request body`
   - `📱 Found X FCM token(s)` OR `⚠️ No FCM tokens found`
   - `📤 Final response`

**Option B: Check Webhook Response**
1. Go to **Database** → **Webhooks**
2. Click on your `notifications` webhook
3. Check **Logs** or **History**
4. Expand the most recent execution
5. View the **Response Body**

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

**Run this SQL query:**

```sql
-- Check if the artisan (recipient) has an FCM token
-- Replace with the artisan ID from your booking: ad12651d-c1fc-44bf-9cc0-5c493dcfc8d7

SELECT 
  user_id,
  LEFT(token, 20) || '...' as token_preview,
  device_type,
  updated_at
FROM fcm_tokens 
WHERE user_id = 'ad12651d-c1fc-44bf-9cc0-5c493dcfc8d7';
```

**If no rows returned:**
- The artisan (Abdul Ibrahim) needs to:
  1. Open the Flutter app on their device
  2. Log in
  3. Grant notification permissions
  4. The token will be saved automatically

**Your user (541a0dc2-6eef-4a55-8028-f79d6afeecb4) has a token:**
- Token: `cz19U_VwuVl7vXZSyZHO...` ✅
- This is why you can receive notifications

## Step 4: Enable Realtime for Notifications Table (Optional)

The Realtime warning is not critical for webhooks, but if you want to fix it:

**In Supabase Dashboard:**
1. Go to **Database** → **Tables**
2. Find the `notifications` table
3. Click on it
4. Go to **Settings** or **Replication**
5. Enable **Realtime** for this table

**OR run this SQL:**

```sql
-- Enable Realtime for notifications table
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
```

**Note:** This is only needed if you're using Realtime subscriptions in your Flutter app. Webhooks work independently.

## Step 5: Test the Full Flow

1. **Create a booking** (you just did this ✅)
2. **Check if notification was created:**
   ```sql
   SELECT * FROM notifications 
   WHERE type = 'booking' 
   ORDER BY created_at DESC 
   LIMIT 1;
   ```
3. **Check Edge Function logs** - Should show webhook was triggered
4. **Check if artisan has FCM token** - If not, they need to open the app

## Most Likely Issue

**The artisan (recipient) doesn't have an FCM token saved.**

When you created the booking, a notification was inserted into the `notifications` table, which triggered the webhook. The Edge Function ran successfully (200 response), but it likely returned:

```json
{
  "success": true,
  "message": "No devices registered",
  "diagnostic": "No FCM tokens found in database for this user..."
}
```

**Solution:** The artisan needs to:
1. Open the app
2. Log in
3. Grant notification permissions
4. Token will be saved automatically

## Quick Checklist

- [ ] Remove old `on-message-created` webhook (fix 404)
- [ ] Check Edge Function logs for actual response
- [ ] Verify recipient (artisan) has FCM token
- [ ] Enable Realtime for notifications table (optional)
- [ ] Test with a user who has an FCM token

## Next Steps

1. **Remove the old webhook** to stop the 404 errors
2. **Check the Edge Function logs** to see the actual response
3. **Have the artisan open the app** so their FCM token gets saved
4. **Test again** - notifications should work once the artisan has a token




