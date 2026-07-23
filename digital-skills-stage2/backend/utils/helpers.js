const crypto = require("node:crypto");

function sanitizeString(value, maxLength = 1000) {
  return String(value ?? "")
    .replace(/<[^>]*>/g, "")
    .replace(/[\u0000-\u001F\u007F]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function hash(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function safeEqual(expected, actual) {
  const expectedBuffer = Buffer.from(String(expected));
  const actualBuffer = Buffer.from(String(actual));
  return (
    expectedBuffer.length === actualBuffer.length &&
    crypto.timingSafeEqual(expectedBuffer, actualBuffer)
  );
}

function getIpAddress(request) {
  const forwarded = String(request.headers["x-forwarded-for"] ?? "");
  return (forwarded.split(",")[0] || request.ip || "unknown").trim();
}

function normalizePrivateKey(key) {
  return String(key ?? "").replace(/\\n/g, "\n");
}

function getAllowedOrigins() {
  return String(process.env.FRONTEND_URL ?? "http://localhost:3000")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
}

function parsePositiveInteger(value, fallback) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

module.exports = {
  escapeHtml,
  getAllowedOrigins,
  getIpAddress,
  hash,
  normalizePrivateKey,
  parsePositiveInteger,
  safeEqual,
  sanitizeString
};
