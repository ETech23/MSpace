const crypto = require("node:crypto");
const { AppError } = require("../middleware/errorHandler");
const { safeEqual } = require("../utils/helpers");
const { FirestoreService } = require("../services/FirestoreService");
const PaystackService = require("../services/PaystackService");
const EmailService = require("../services/EmailService");
const logger = require("../utils/logger");

class WebhookController {
  async paystack(request, response, next) {
    try {
      this.verifySignature(request);

      const event = request.body;
      if (event.event !== "charge.success") {
        logger.info("Ignored Paystack webhook event", { event: event.event });
        response.status(200).json({ received: true, ignored: true });
        return;
      }

      const reference = String(event.data?.reference ?? "");
      if (!reference) {
        throw new AppError(400, "Webhook is missing a payment reference.");
      }

      const payment = await FirestoreService.getPayment(reference);
      const applicantId = String(payment.applicantId ?? "").toUpperCase();
      const transaction = await PaystackService.verifyTransaction(reference);
      const receipt = await FirestoreService.persistSuccessfulPayment(
        applicantId,
        reference,
        transaction,
        "paystack_webhook"
      );
      const applicant = await FirestoreService.getApplicant(applicantId);
      await EmailService.sendPaymentSuccess(applicant, receipt);

      logger.info("Paystack webhook processed", { applicantId, reference });
      response.status(200).json({ received: true });
    } catch (error) {
      next(error);
    }
  }

  verifySignature(request) {
    const secretKey = process.env.PAYSTACK_WEBHOOK_SECRET || process.env.PAYSTACK_SECRET_KEY;
    const signature = String(request.headers["x-paystack-signature"] ?? "");
    if (!secretKey || !signature) {
      throw new AppError(401, "Missing Paystack webhook signature.");
    }

    const computed = crypto
      .createHmac("sha512", secretKey)
      .update(request.rawBody || Buffer.from(JSON.stringify(request.body)))
      .digest("hex");

    if (!safeEqual(computed, signature)) {
      throw new AppError(401, "Invalid Paystack webhook signature.");
    }
  }
}

module.exports = new WebhookController();
