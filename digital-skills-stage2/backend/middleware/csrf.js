const crypto = require("node:crypto");
const { safeEqual } = require("../utils/helpers");

const CSRF_TTL_MS = 2 * 60 * 60 * 1000;

function getCsrfSecret() {
  const secret = String(process.env.ADMIN_API_KEY ?? process.env.PAYSTACK_SECRET_KEY ?? "");

  if (!secret) {
    throw new Error("CSRF secret is not configured.");
  }

  return secret;
}

function createCsrfToken() {
  const issuedAt = Date.now().toString(36);
  const nonce = crypto.randomBytes(24).toString("hex");
  const payload = `${issuedAt}.${nonce}`;
  const signature = crypto.createHmac("sha256", getCsrfSecret()).update(payload).digest("hex");
  return `${payload}.${signature}`;
}

function isValidCsrfToken(token) {
  const parts = String(token ?? "").split(".");
  if (parts.length !== 3) {
    return false;
  }

  const [issuedAt, nonce, signature] = parts;
  const timestamp = Number.parseInt(issuedAt, 36);
  if (!Number.isFinite(timestamp) || timestamp <= 0) {
    return false;
  }

  if (Date.now() - timestamp > CSRF_TTL_MS) {
    return false;
  }

  const payload = `${issuedAt}.${nonce}`;
  const expectedSignature = crypto.createHmac("sha256", getCsrfSecret()).update(payload).digest("hex");
  return safeEqual(expectedSignature, signature);
}

function issueCsrfToken(request, response) {
  response.status(200).json({ csrfToken: createCsrfToken() });
}

function requireCsrf(request, response, next) {
  if (request.method === "GET" || request.method === "HEAD" || request.method === "OPTIONS") {
    next();
    return;
  }

  if (request.path === "/api/paystack/webhook") {
    next();
    return;
  }

  const headerToken = String(request.headers["x-csrf-token"] ?? "");

  if (!headerToken || !isValidCsrfToken(headerToken)) {
    response.status(403).json({ error: "Security token is invalid or expired." });
    return;
  }

  next();
}

module.exports = {
  issueCsrfToken,
  requireCsrf
};
