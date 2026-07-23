const express = require("express");
const EmailController = require("../controllers/EmailController");
const { requireAdmin } = require("../middleware/auth");
const { adminLimiter } = require("../middleware/rateLimiter");

const router = express.Router();

router.post("/payment-success", adminLimiter, requireAdmin, EmailController.sendPaymentSuccess);

module.exports = router;
