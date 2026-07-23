const { paystackClient } = require("../config/paystack");
const { AppError } = require("../middleware/errorHandler");
const { AMOUNT_KOBO, CURRENCY } = require("./FirestoreService");

class PaystackService {
  async initializeTransaction({ applicantId, email, reference }) {
    if (!process.env.PAYSTACK_SECRET_KEY) {
      throw new AppError(500, "Paystack secret key is not configured.");
    }

    const response = await paystackClient.post("/transaction/initialize", {
      email,
      amount: AMOUNT_KOBO,
      currency: CURRENCY,
      reference,
      callback_url: `${process.env.FRONTEND_URL?.split(",")[0] ?? "https://mspaceapp.com"}/success`,
      metadata: {
        applicant_id: applicantId,
        stage: "Stage2"
      }
    });

    if (!response.data?.status) {
      throw new AppError(502, response.data?.message || "Paystack initialization failed.");
    }

    return response.data.data;
  }

  async verifyTransaction(reference) {
    if (!process.env.PAYSTACK_SECRET_KEY) {
      throw new AppError(500, "Paystack secret key is not configured.");
    }

    const response = await paystackClient.get(
      `/transaction/verify/${encodeURIComponent(reference)}`
    );

    if (!response.data?.status || !response.data?.data) {
      throw new AppError(502, response.data?.message || "Paystack verification failed.");
    }

    const transaction = response.data.data;
    if (
      transaction.status !== "success" ||
      transaction.amount !== AMOUNT_KOBO ||
      transaction.currency !== CURRENCY
    ) {
      throw new AppError(402, "Payment was not successful.");
    }

    return transaction;
  }
}

module.exports = new PaystackService();
