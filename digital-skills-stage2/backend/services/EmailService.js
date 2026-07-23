const axios = require("axios");
const { FirestoreService } = require("./FirestoreService");
const logger = require("../utils/logger");

class EmailService {
  async sendPaymentSuccess(applicant, receipt) {
    const webhookUrl = process.env.GOOGLE_APPS_SCRIPT_WEBHOOK;
    const payload = {
      applicantId: applicant.applicantId,
      email: applicant.email,
      firstName: applicant.firstName,
      paymentStatus: "Paid",
      paymentReference: receipt.paymentReference,
      amount: receipt.amountPaid,
      currentStage: applicant.stage || "Stage2"
    };

    if (!webhookUrl) {
      await FirestoreService.logEmail({
        applicantId: applicant.applicantId,
        paymentReference: receipt.paymentReference,
        receiptNumber: receipt.receiptNumber,
        status: "Skipped",
        reason: "GOOGLE_APPS_SCRIPT_WEBHOOK is not configured"
      });
      return;
    }

    try {
      const response = await axios.post(webhookUrl, payload, {
        timeout: 20000,
        headers: { "Content-Type": "application/json" }
      });

      await FirestoreService.logEmail({
        applicantId: applicant.applicantId,
        paymentReference: receipt.paymentReference,
        receiptNumber: receipt.receiptNumber,
        status: response.status >= 200 && response.status < 300 ? "Sent" : "Failed",
        statusCode: response.status
      });
    } catch (error) {
      logger.error("Google Apps Script notification failed", {
        applicantId: applicant.applicantId,
        paymentReference: receipt.paymentReference,
        message: error.message
      });

      await FirestoreService.logEmail({
        applicantId: applicant.applicantId,
        paymentReference: receipt.paymentReference,
        receiptNumber: receipt.receiptNumber,
        status: "Failed",
        error: error.message
      });
    }
  }
}

module.exports = new EmailService();
