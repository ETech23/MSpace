# Digital Skills Laptop Support Program - Stage 2

This project contains the completed Next.js frontend and a new Express backend for Render. Firebase Hosting and Firestore are retained. Firebase Cloud Functions have been removed.

## Architecture

- Frontend: Next.js 15, React 19, TypeScript, Tailwind CSS, Framer Motion.
- Hosting: Firebase Hosting on `https://mspaceapp.com`.
- Backend: Node.js and Express deployed on Render.
- API Domain: `https://api.mspaceapp.com`.
- Database: Firestore through Firebase Admin SDK.
- Payments: Paystack Inline plus server-side verification.
- Emails: existing Google Apps Script Web App.

## Frontend Setup

Create `.env.local`:

```env
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=pk_test_22c75596f9b859467ebdbff599ddb826df0e631b
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
```

For production builds:

```env
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=pk_live_your_live_public_key
NEXT_PUBLIC_API_BASE_URL=https://api.mspaceapp.com
```

Install and build:

```powershell
npm install
npm run build
```

Deploy only Hosting and Firestore rules/indexes:

```powershell
npm run deploy
```

## Backend Setup

```powershell
cd backend
npm install
copy .env.example .env
npm run dev
```

Open:

```text
http://localhost:8080/health
```

## Firebase Admin Service Account

1. Open Firebase Console.
2. Go to Project Settings.
3. Open Service Accounts.
4. Generate a new private key.
5. Put the service account values into `backend/.env` or Render environment variables.

Required backend variables:

- `PORT`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `PAYSTACK_PUBLIC_KEY`
- `PAYSTACK_SECRET_KEY`
- `PAYSTACK_WEBHOOK_SECRET`
- `GOOGLE_APPS_SCRIPT_WEBHOOK`
- `FRONTEND_URL`
- `ADMIN_API_KEY`
- `NODE_ENV`

Paystack does not provide a separate webhook secret. Use the same Paystack secret key for `PAYSTACK_SECRET_KEY` and `PAYSTACK_WEBHOOK_SECRET`.

## Paystack Configuration

Testing:

- Frontend public key: Paystack Test Public Key.
- Backend secret key: Paystack Test Secret Key.
- Webhook URL: `https://api.mspaceapp.com/api/paystack/webhook`.
- Callback URL: `https://mspaceapp.com/success`.

Live:

- Frontend public key: Paystack Live Public Key.
- Backend secret key: Paystack Live Secret Key.
- Webhook URL: `https://api.mspaceapp.com/api/paystack/webhook`.
- Callback URL: `https://mspaceapp.com/success`.

## Render Deployment

1. Push the repository to GitHub.
2. Create a Render Blueprint from `render.yaml`.
3. Add all backend environment variables in Render.
4. Deploy the service.
5. Add custom domain `api.mspaceapp.com`.
6. In DNS, point `api.mspaceapp.com` to Render's hostname.
7. Set frontend production env `NEXT_PUBLIC_API_BASE_URL=https://api.mspaceapp.com`.
8. Rebuild and deploy Firebase Hosting.

## Firestore

Deploy rules and indexes:

```powershell
npm run deploy:rules
```

Collections used:

- `Applicants`
- `Payments`
- `AuditLogs`
- `EmailLogs`
- `StageHistory`

## Testing

Import this Postman collection:

```text
backend/postman/Digital-Skills-Stage2.postman_collection.json
```

Recommended order:

1. `GET /health`
2. `GET /api/csrf`
3. `POST /api/applicants`
4. Complete Paystack test checkout in the frontend.
5. `POST /api/payments/verify`
6. Check admin dashboard endpoints.

## Migration Checklist

- Cloud Functions removed.
- Firebase Hosting retained.
- Firestore connected via Admin SDK.
- Paystack integration updated for Express.
- Frontend API endpoints updated to Render API.
- Render deployment configured with `render.yaml`.
- Google Apps Script integration preserved.
