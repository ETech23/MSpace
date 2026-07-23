const { sanitizeString } = require("../utils/helpers");

function sanitizeValue(value) {
  if (Array.isArray(value)) {
    return value.map(sanitizeValue);
  }

  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .filter(([key]) => !key.startsWith("$") && !key.includes("."))
        .map(([key, item]) => [sanitizeString(key, 120), sanitizeValue(item)])
    );
  }

  if (typeof value === "string") {
    return sanitizeString(value);
  }

  return value;
}

function sanitizeRequest(request, _response, next) {
  if (request.body) {
    request.body = sanitizeValue(request.body);
  }

  if (request.query) {
    request.query = sanitizeValue(request.query);
  }

  if (request.params) {
    request.params = sanitizeValue(request.params);
  }

  next();
}

module.exports = {
  sanitizeRequest,
  sanitizeValue
};
