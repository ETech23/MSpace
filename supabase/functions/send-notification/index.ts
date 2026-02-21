// supabase/functions/send-notification/index.ts
// ✅ Uses FCM V1 API with Service Account

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface NotificationPayload {
  userId: string
  title: string
  body: string
  type: string
  subType?: string
  relatedId?: string
  data?: Record<string, any>
}


// ✅ Get OAuth2 access token from Firebase service account
async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  
  // Create JWT header and payload
  const jwtHeader = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
  const jwtPayload = btoa(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  }))

  const unsignedToken = `${jwtHeader}.${jwtPayload}`

  // Import private key for signing
  const pemHeader = "-----BEGIN PRIVATE KEY-----"
  const pemFooter = "-----END PRIVATE KEY-----"
  const pemContents = serviceAccount.private_key
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s/g, "")

  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )

  // Sign the JWT
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsignedToken)
  )

  const base64Signature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "")

  const signedJwt = `${unsignedToken}.${base64Signature}`

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  })

  if (!tokenResponse.ok) {
    const error = await tokenResponse.text()
    throw new Error(`Failed to get access token: ${error}`)
  }

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    console.log("📩 FCM V1 Edge Function invoked at", new Date().toISOString())

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")

    console.log("🔑 Environment check:")
    console.log(`   Supabase URL: ${supabaseUrl ? "✓" : "✗"}`)
    console.log(`   Service Role Key: ${serviceRoleKey ? "✓" : "✗"}`)
    console.log(`   Firebase Service Account: ${serviceAccountJson ? "✓" : "✗"}`)

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing Supabase credentials")
    }

    if (!serviceAccountJson) {
      throw new Error("Missing FIREBASE_SERVICE_ACCOUNT - set this in Edge Function secrets")
    }

    const serviceAccount = JSON.parse(serviceAccountJson)
    const supabase = createClient(supabaseUrl, serviceRoleKey)

    // Parse incoming payload
    let body: any
    try {
      body = await req.json()
      console.log("📦 Request body received")
    } catch (e) {
      throw new Error("Invalid JSON payload")
    }

    // Detect payload format (webhook vs direct call)
    const record = body.record || body

    // Early exit for processed notifications (webhook mode)
const { data: existing, error: dupError } = await supabase
  .from("notifications")
  .select("id")
  .eq("id", record.id)
  .eq("processed", true)
  .single();

if (existing) {
  console.log("⛔ Notification already processed:", record.id);
  return new Response(JSON.stringify({ success: true, skipped: true }));
}

    let payload: NotificationPayload

    if (record && (body.table === "notifications" || body.type === "INSERT")) {
      console.log("✅ Detected webhook payload from notifications table")
      payload = {
        userId: record.user_id,
        title: record.title ?? "Notification",
        body: record.body ?? "",
        type: record.type ?? "system",
        subType: record.sub_type,
        relatedId: record.related_id,
        data: typeof record.data === "object" ? record.data : {},
      }
    } else if (body.userId || body.user_id) {
      console.log("✅ Detected direct payload")
      payload = {
        userId: body.userId || body.user_id,
        title: body.title ?? "Notification",
        body: body.body ?? "",
        type: body.type ?? "system",
        subType: body.subType || body.sub_type,
        relatedId: body.relatedId || body.related_id,
        data: body.data ?? {},
      }
    } else {
      throw new Error("Invalid payload format")
    }

    console.log(`📋 Payload: User=${payload.userId}, Title="${payload.title}", Type=${payload.type}`)

    // Fetch FCM tokens
    console.log("🔍 Fetching FCM tokens...")
    const { data: tokens, error: tokenError } = await supabase
      .from("fcm_tokens")
      .select("token, device_type")
      .eq("user_id", payload.userId)

    if (tokenError) {
      console.error("❌ Error fetching tokens:", tokenError)
      throw tokenError
    }

    if (!tokens || tokens.length === 0) {
      console.log("⚠️ No FCM tokens for user:", payload.userId)
      return new Response(
        JSON.stringify({ success: true, message: "No devices registered" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    console.log(`📱 Found ${tokens.length} FCM token(s)`)

    // Get OAuth2 access token
    console.log("🔐 Getting OAuth2 access token...")
    const accessToken = await getAccessToken(serviceAccount)
    console.log("✅ Access token obtained")

    // Send to all devices using FCM V1 API

    // In your Edge Function, replace the "Send to all devices" section with this:

console.log(`📤 About to send to ${tokens.length} token(s)`)

// Log each unique token
const uniqueTokens = new Set()
tokens.forEach((t, idx) => {
  console.log(`  Token ${idx + 1}: ${t.token.substring(0, 30)}... (${t.device_type})`)
  uniqueTokens.add(t.token)
})

console.log(`🔍 Unique tokens: ${uniqueTokens.size}, Total tokens: ${tokens.length}`)

if (uniqueTokens.size !== tokens.length) {
  console.log(`⚠️ WARNING: DUPLICATE TOKENS DETECTED!`)
}

// Send to all devices using FCM V1 API
const results = await Promise.all(
  tokens.map(async ({ token, device_type }, index) => {
    try {
      console.log(`📤 [${index + 1}/${tokens.length}] Sending to ${device_type} token: ${token.substring(0, 20)}...`)

          // Ensure data values are strings (FCM requires string map values)
          const safeData = {
            type: payload.type,
            subType: payload.subType ?? "",
            relatedId: String(payload.relatedId ?? ""),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            ...(payload.data || {}),
          };

          // Convert all values to strings (objects are JSON-stringified)
          for (const k of Object.keys(safeData)) {
            const v = safeData[k];
            if (typeof v === 'object') {
              try {
                safeData[k] = JSON.stringify(v);
              } catch {
                safeData[k] = String(v);
              }
            } else {
              safeData[k] = String(v ?? '');
            }
          }

          // Log safe data for debugging
          console.log('📋 safeData:', safeData);

          const fcmRequestBody = {
            message: {
              token: token,
              notification: {
                title: payload.title,
                body: payload.body,
              },
              data: safeData,
              android: {
                priority: "high",
                notification: {
                  channel_id: getChannelId(payload.type),
                  sound: "default",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            },
          };

          const fcmResponse = await fetch(
            `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${accessToken}`,
              },
              body: JSON.stringify(fcmRequestBody),
            }
          )

          const responseText = await fcmResponse.text()
          console.log(`📥 FCM Response (${fcmResponse.status}):`, responseText.substring(0, 200))

          if (!fcmResponse.ok) {
            console.error(`❌ FCM error for token ${token.substring(0, 20)}`)

            let removeToken = false;
            try {
              const parsed = JSON.parse(responseText);
              const errMsg = (parsed?.error?.message || '').toString().toLowerCase();
              const errCode = parsed?.error?.code;

              // Consider token-specific errors only (avoid removing for payload/format issues)
              const isTokenError = /not_registered|invalidregistration|unregistered|registration-token-not-found|not_found/.test(errMsg) || errCode === 404;

              console.log('📥 FCM parsed error message:', parsed?.error?.message || parsed);

              if (isTokenError) removeToken = true;
            } catch (e) {
              console.log('⚠️ Could not parse FCM response JSON; not removing token. Raw response:', responseText);
            }

            if (removeToken) {
              console.log(`🗑️ Removing invalid token`)
              await supabase.from("fcm_tokens").delete().eq("token", token)
            } else {
              console.log('⚠️ FCM error was not token-related; not removing token')
            }

            return { token: token.substring(0, 20), success: false, error: responseText.substring(0, 100) }
          }

          const fcmResult = JSON.parse(responseText)
          console.log(`✅ FCM Success! Message: ${fcmResult.name}`)

          return { token: token.substring(0, 20), success: true, messageId: fcmResult.name }
        } catch (err) {
          console.error(`❌ Exception:`, err.message)
          return { token: token.substring(0, 20), success: false, error: err.message }
        }
      })
    )

    const successCount = results.filter((r) => r.success).length
    console.log(`📊 Results: ${successCount}/${tokens.length} sent successfully`)

    return new Response(
      JSON.stringify({
        success: true,
        sent: successCount,
        total: tokens.length,
        results,
        timestamp: new Date().toISOString(),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err) {
    console.error("❌ Edge function error:", err.message)
    console.error("Stack:", err.stack)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: err.message,
        timestamp: new Date().toISOString(),
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    )
  }
})

function getChannelId(type: string): string {
  switch (type) {
    case "message":
      return "messages_channel"
    case "booking":
      return "bookings_channel"
    case "system":
      return "system_channel"
    case "job":
      return "jobs_channel"
    default:
      return "default_channel"
  }
}