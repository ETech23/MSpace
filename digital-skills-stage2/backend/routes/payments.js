const express = require("express");
const PaymentController = require("../controllers/PaymentController");
const { paymentLimiter } = require("../middleware/rateLimiter");
const { validatePaymentVerification } = require("../middleware/validation");

const router = express.Router();

router.post("/initialize", paymentLimiter, PaymentController.initialize);
router.post("/verify", paymentLimiter, validatePaymentVerification, PaymentController.verify);

module.exports = router;
