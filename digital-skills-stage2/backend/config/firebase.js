const admin = require("firebase-admin");
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

function initializeFirebase() {
  if (admin.apps.length) {
    return admin.app();
  }

  const serviceAccount = getServiceAccount();

  try {
    return admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.projectId || serviceAccount.project_id
    });
  } catch (error) {
    throw new Error(
      `Firebase Admin failed to initialize. Check FIREBASE_SERVICE_ACCOUNT_JSON_BASE64, FIREBASE_SERVICE_ACCOUNT_JSON, or FIREBASE_PRIVATE_KEY for a valid PEM private key. Original error: ${error.message}`
    );
  }
}

initializeFirebase();

module.exports = {
  admin,
  db: admin.firestore()
};
