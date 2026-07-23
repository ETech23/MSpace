const { AppError } = require("../middleware/errorHandler");
const EmailService = require("../services/EmailService");
const { FirestoreService } = require("../services/FirestoreService");

class EmailController {
  async sendPaymentSuccess(request, response, next) {
    try {
      const applicantId = String(request.body?.applicantId ?? "").toUpperCase();
      const paymentReference = String(request.body?.paymentReference ?? "");
      if (!applicantId || !paymentReference) {
        throw new AppError(400, "Applicant ID and payment reference are required.");
      }

      const applicant = await FirestoreService.getApplicant(applicantId);
      const payment = await FirestoreService.getPayment(paymentReference);
      await EmailService.sendPaymentSuccess(applicant, {
        amountPaid: Number(payment.amountPaid ?? payment.amount ?? 0),
        paymentReference,
        receiptNumber: String(payment.receiptNumber ?? "")
      });

      response.status(200).json({ sent: true });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new EmailController();
