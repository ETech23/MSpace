const admin = require("firebase-admin");
const { AppError } = require("../middleware/errorHandler");
const { normalizePrivateKey } = require("../utils/helpers");

function normalizeServiceAccount(serviceAccount) {
  if (!serviceAccount || typeof serviceAccount !== "object") {
    return serviceAccount;
  }

  const normalizedServiceAccount = { ...serviceAccount };

  if (normalizedServiceAccount.private_key) {
    normalizedServiceAccount.private_key = normalizePrivateKey(normalizedServiceAccount.private_key);
  }

  if (normalizedServiceAccount.privateKey) {
    normalizedServiceAccount.privateKey = normalizePrivateKey(normalizedServiceAccount.privateKey);
  }

  return normalizedServiceAccount;
}

function parseServiceAccountPayload(payload) {
  const parsedPayload = JSON.parse(payload);

  if (typeof parsedPayload === "string") {
    return normalizeServiceAccount(JSON.parse(parsedPayload));
  }

  return normalizeServiceAccount(parsedPayload);
}

function getServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON_BASE64) {
    return parseServiceAccountPayload(
      Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_JSON_BASE64, "base64").toString("utf8")
    );
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return parseServiceAccountPayload(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = normalizePrivateKey(process.env.FIREBASE_PRIVATE_KEY);

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Firebase Admin environment variables are not configured.");
  }

  return {
    projectId,
    clientEmail,
    privateKey
  };
}

let firebaseApp = null;
let firestoreDb = null;
let firebaseInitError = null;

function initializeFirebase() {
  if (firebaseApp) {
    return firebaseApp;
  }

  try {
    const serviceAccount = getServiceAccount();

    firebaseApp = admin.apps.length
      ? admin.app()
      : admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.projectId || serviceAccount.project_id
      });
    firestoreDb = admin.firestore();
    firebaseInitError = null;
    return firebaseApp;
  } catch (error) {
    firebaseInitError = new AppError(
      503,
      `Firebase Admin is unavailable. Check FIREBASE_SERVICE_ACCOUNT_JSON_BASE64, FIREBASE_SERVICE_ACCOUNT_JSON, or FIREBASE_PRIVATE_KEY. Original error: ${error.message}`
    );
    firebaseInitError.cause = error;
    return null;
  }
}

function getDb() {
  if (firestoreDb) {
    return firestoreDb;
  }

  if (firebaseInitError) {
    throw firebaseInitError;
  }

  initializeFirebase();

  if (firestoreDb) {
    return firestoreDb;
  }

  throw firebaseInitError || new AppError(503, "Firebase Admin is unavailable.");
}

function isFirebaseReady() {
  return Boolean(firestoreDb) && !firebaseInitError;
}

module.exports = {
  admin,
  getDb,
  isFirebaseReady
};
