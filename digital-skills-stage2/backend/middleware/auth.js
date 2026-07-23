const { safeEqual } = require("../utils/helpers");

function requireAdmin(request, response, next) {
  const configuredKey = process.env.ADMIN_API_KEY;
  const providedKey = String(request.headers["x-admin-key"] ?? "");

  if (!configuredKey || !providedKey || !safeEqual(configuredKey, providedKey)) {
    response.status(401).json({ error: "Unauthorized admin request." });
    return;
  }

  next();
}

module.exports = {
  requireAdmin
};
