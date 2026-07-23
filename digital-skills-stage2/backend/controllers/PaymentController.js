const { AppError } = require("../middleware/errorHandler");
const { isValidApplicantId } = require("../utils/validators");
const { FirestoreService } = require("../services/FirestoreService");
const PaystackService = require("../services/PaystackService");
const EmailService = require("../services/EmailService");

class PaymentController {
  async initialize(request, response, next) {
    try {
      const applicantId = String(request.body?.applicantId ?? "").toUpperCase();
      if (!isValidApplicantId(applicantId)) {
        throw new AppError(400, "Invalid Applicant ID.");
      }

      const applicant = await FirestoreService.getApplicant(applicantId);
      const payment = await PaystackService.initializeTransaction({
        applicantId,
        email: applicant.email,
        reference: applicant.paymentReference
      });

      response.status(200).json({
        applicantId,
        amount: payment.amount,
        currency: payment.currency,
        email: applicant.email,
        paymentReference: payment.reference,
        authorizationUrl: payment.authorization_url,
        accessCode: payment.access_code,
        publicKey: process.env.PAYSTACK_PUBLIC_KEY
      });
    } catch (error) {
      next(error);
    }
  }

  async verify(request, response, next) {
    try {
      const applicantId = String(request.body?.applicantId ?? "").toUpperCase();
      const reference = String(request.body?.reference ?? "");
      if (!isValidApplicantId(applicantId) || !reference) {
        throw new AppError(400, "Invalid payment verification request.");
      }

      const transaction = await PaystackService.verifyTransaction(reference);
      const receipt = await FirestoreService.persistSuccessfulPayment(
        applicantId,
        reference,
        transaction,
        "client_callback"
      );
      const applicant = await FirestoreService.getApplicant(applicantId);
      await EmailService.sendPaymentSuccess(applicant, receipt);

      response.status(200).json(receipt);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new PaymentController();
