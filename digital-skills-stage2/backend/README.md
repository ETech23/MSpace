# Digital Skills Stage 2 Express Backend

This backend replaces Firebase Cloud Functions with a secure Node.js and Express API designed for Render.

## Routes

- `GET /health`
- `GET /api/csrf`
- `POST /api/applicants`
- `GET /api/applicants/:id`
- `PUT /api/applicants/:id`
- `POST /api/payments/initialize`
- `POST /api/payments/verify`
- `POST /api/paystack/webhook`
- `GET /api/admin/dashboard`
- `GET /api/admin/applicants`
- `GET /api/admin/payments`
- `GET /api/admin/export`
- `POST /api/emails/payment-success`

## Install

```powershell
cd digital-skills-stage2\backend
npm install
```

## Firebase Admin SDK

In Firebase Console:

1. Open Project Settings.
2. Open Service Accounts.
3. Generate a new private key.
4. Prefer the base64 method for Render because it avoids private-key line break errors.

PowerShell base64 command:

```powershell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Content .\firebase-service-account.json -Raw)))
```

Add the result to Render:

- `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64`

If you use the direct key variables instead, Render can accept either real line breaks or escaped `\n` sequences, and the backend now strips surrounding quotes automatically.

Alternative manual values:

   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_CLIENT_EMAIL`
   - `FIREBASE_PRIVATE_KEY`

Keep the private key line breaks as `\n` when pasting into Render, or paste the key as-is with actual line breaks.

## Environment Variables

Create `backend/.env` locally:

```env
PORT=8080
NODE_ENV=development
FRONTEND_URL=http://localhost:3000,https://mspaceapp.com
FIREBASE_PROJECT_ID=naco-d2738
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@naco-d2738.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n"
PAYSTACK_PUBLIC_KEY=pk_test_22c75596f9b859467ebdbff599ddb826df0e631b
PAYSTACK_SECRET_KEY=sk_test_your_secret_key
PAYSTACK_WEBHOOK_SECRET=sk_test_your_secret_key
GOOGLE_APPS_SCRIPT_WEBHOOK=https://script.google.com/macros/s/your-script-id/exec
ADMIN_API_KEY=replace-with-a-long-random-admin-key
```

Paystack does not provide a separate webhook secret. Use the same secret key for `PAYSTACK_SECRET_KEY` and `PAYSTACK_WEBHOOK_SECRET`.

## Local Development

```powershell
npm run dev
```

Open:

```text
http://localhost:8080/health
```

Set the frontend `.env.local` to:

```env
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=pk_test_22c75596f9b859467ebdbff599ddb826df0e631b
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
```

## Paystack

Use these Paystack URLs:

- Test webhook: `https://api.mspaceapp.com/api/paystack/webhook`
- Live webhook: `https://api.mspaceapp.com/api/paystack/webhook`
- Callback URL: `https://mspaceapp.com/success`

The frontend uses Paystack Inline, then the backend verifies every transaction using Paystack's verify endpoint before Firestore is updated.

## Render Deployment

1. Push this project to GitHub.
2. In Render, create a new Blueprint.
3. Select this repository.
4. Render reads `render.yaml`.
5. Add all environment variables marked `sync: false`.
6. Deploy.
7. Add custom domain `api.mspaceapp.com`.
8. Point DNS CNAME for `api` to Render's provided hostname.

## Google Apps Script

After successful payment, the backend POSTs this payload to `GOOGLE_APPS_SCRIPT_WEBHOOK`:

```json
{
  "applicantId": "DSP-2026-000458",
  "email": "applicant@example.com",
  "firstName": "Ada",
  "paymentStatus": "Paid",
  "paymentReference": "DSP2026000458-...",
  "amount": 100000,
  "currentStage": "Stage2"
}
```

## Monitoring

Use Render Logs for:

- request logs from Morgan
- payment events
- webhook events
- Firestore errors
- email automation errors

Common issues:

- `Firebase Admin environment variables are not configured`: check service account values.
- `Invalid Paystack webhook signature`: confirm `PAYSTACK_WEBHOOK_SECRET` equals the current Paystack secret key.
- `Origin is not allowed by CORS`: add the frontend origin to `FRONTEND_URL`.
- `Security token is invalid or expired`: refresh the frontend page and retry.
