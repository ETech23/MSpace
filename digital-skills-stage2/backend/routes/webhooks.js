const express = require("express");
const WebhookController = require("../controllers/WebhookController");

const router = express.Router();

router.post("/paystack/webhook", WebhookController.paystack.bind(WebhookController));

module.exports = router;
