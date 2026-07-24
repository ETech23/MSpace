const admin = require("firebase-admin");
const { normalizePrivateKey } = require("../utils/helpers");

function getServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON_BASE64) {
    const serviceAccount = JSON.parse(
      Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_JSON_BASE64, "base64").toString("utf8")
    );

    if (serviceAccount.private_key) {
      serviceAccount.private_key = normalizePrivateKey(serviceAccount.private_key);
    }

    return serviceAccount;
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);

    if (serviceAccount.private_key) {
      serviceAccount.private_key = normalizePrivateKey(serviceAccount.private_key);
    }

    return serviceAccount;
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

  return admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.projectId || serviceAccount.project_id
  });
}

initializeFirebase();

module.exports = {
  admin,
  db: admin.firestore()
};
