require("dotenv").config();

const compression = require("compression");
const cookieParser = require("cookie-parser");
const cors = require("cors");
const express = require("express");
const helmet = require("helmet");
const morgan = require("morgan");
const applicantRoutes = require("./routes/applicants");
const paymentRoutes = require("./routes/payments");
const webhookRoutes = require("./routes/webhooks");
const adminRoutes = require("./routes/admin");
const emailRoutes = require("./routes/emails");
const { errorHandler, notFound } = require("./middleware/errorHandler");
const { generalLimiter } = require("./middleware/rateLimiter");
const { sanitizeRequest } = require("./middleware/sanitize");
const { issueCsrfToken, requireCsrf } = require("./middleware/csrf");
const { getAllowedOrigins } = require("./utils/helpers");
const logger = require("./utils/logger");

const app = express();
const allowedOrigins = getAllowedOrigins();

app.set("trust proxy", 1);

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: "cross-origin" }
  })
);
app.use(compression());
app.use(
  cors({
    credentials: true,
    origin(origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error("Origin is not allowed by CORS."));
    }
  })
);
app.use(
  express.json({
    limit: "128kb",
    verify(request, _response, buffer) {
      request.rawBody = buffer;
    }
  })
);
app.use(express.urlencoded({ extended: false, limit: "64kb" }));
app.use(cookieParser());
app.use(
  morgan("combined", {
    stream: {
      write(message) {
        logger.info(message.trim());
      }
    }
  })
);
app.use(generalLimiter);
app.use(sanitizeRequest);

app.get("/health", (_request, response) => {
  response.status(200).json({
    ok: true,
    service: "digital-skills-stage2-backend",
    timestamp: new Date().toISOString()
  });
});

app.get("/api/csrf", issueCsrfToken);
app.use(requireCsrf);
app.use("/api/applicants", applicantRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api", webhookRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api/emails", emailRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
