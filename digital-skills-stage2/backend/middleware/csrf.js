const crypto = require("node:crypto");
const { safeEqual } = require("../utils/helpers");

function issueCsrfToken(request, response) {
  const token = crypto.randomBytes(32).toString("hex");
  const secure = process.env.NODE_ENV === "production";

  response.cookie("stage2_csrf", token, {
    httpOnly: true,
    secure,
    sameSite: secure ? "none" : "lax",
    maxAge: 2 * 60 * 60 * 1000,
    path: "/"
  });

  response.status(200).json({ csrfToken: token });
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

  const cookieToken = String(request.cookies?.stage2_csrf ?? "");
  const headerToken = String(request.headers["x-csrf-token"] ?? "");

  if (!cookieToken || !headerToken || !safeEqual(cookieToken, headerToken)) {
    response.status(403).json({ error: "Security token is invalid or expired." });
    return;
  }

  next();
}

module.exports = {
  issueCsrfToken,
  requireCsrf
};
