const logger = require("../utils/logger");

class AppError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
  }
}

function notFound(request, response) {
  response.status(404).json({ error: `Route not found: ${request.method} ${request.originalUrl}` });
}

function errorHandler(error, request, response, _next) {
  const statusCode = error.statusCode || 500;
  const message = error.isOperational ? error.message : "Unexpected server error.";

  logger.error("Request failed", {
    method: request.method,
    path: request.originalUrl,
    statusCode,
    message: error.message,
    stack: process.env.NODE_ENV === "production" ? undefined : error.stack
  });

  response.status(statusCode).json({ error: message });
}

module.exports = {
  AppError,
  errorHandler,
  notFound
};
