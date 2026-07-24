const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getDb } = require("../config/firebase");
const { AppError } = require("../middleware/errorHandler");
const { buildPaymentReference, buildReceiptNumber } = require("../utils/receipt");

const AMOUNT_KOBO = 100000;
const CURRENCY = "NGN";
const STAGE = "Stage2";
const UNDER_REVIEW = "UnderReview";

class FirestoreService {
  get db() {
    return getDb();
  }

  applicantsCollection() {
    return this.db.collection("Applicants");
  }

  paymentsCollection() {
    return this.db.collection("Payments");
  }

  async createApplicant(payload, metadata) {
    const applicantId = payload.applicantId.toUpperCase();
    const applicantRef = this.applicantsCollection().doc(applicantId);
    const paymentReference = buildPaymentReference(applicantId);
    const paymentRef = this.paymentsCollection().doc(paymentReference);

    await this.db.runTransaction(async (transaction) => {
      const existing = await transaction.get(applicantRef);
      if (existing.exists) {
        throw new AppError(409, "This Applicant ID has already completed Stage 2.");
      }

      transaction.create(applicantRef, {
        ...payload,
        applicantId,
        email: payload.email.toLowerCase(),
        age: Number(payload.age),
        socialFollowers: Number(payload.socialFollowers),
        submissionTime: FieldValue.serverTimestamp(),
        ipAddress: metadata.ipAddress,
        browser: metadata.browser,
        paymentStatus: "Pending",
        stage: STAGE,
        verificationStatus: "SubmittedPendingPayment",
        paymentReference,
        receiptNumber: null,
        updatedAt: FieldValue.serverTimestamp()
      });

      transaction.create(paymentRef, {
        applicantId,
        amount: AMOUNT_KOBO,
        currency: CURRENCY,
        paymentReference,
        paymentStatus: "Pending",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });

      transaction.create(this.db.collection("StageHistory").doc(), {
        applicantId,
        fromStage: "Stage1",
        toStage: STAGE,
        status: "SubmittedPendingPayment",
        createdAt: FieldValue.serverTimestamp()
      });

      transaction.create(this.db.collection("AuditLogs").doc(), {
        action: "stage2_application_created",
        applicantId,
        ipAddress: metadata.ipAddress,
        browser: metadata.browser,
        createdAt: FieldValue.serverTimestamp()
      });
    });

    return {
      applicantId,
      amount: AMOUNT_KOBO,
      currency: CURRENCY,
      email: payload.email.toLowerCase(),
      paymentReference
    };
  }

  async getApplicant(applicantId) {
    const snapshot = await this.applicantsCollection().doc(applicantId.toUpperCase()).get();
    if (!snapshot.exists) {
      throw new AppError(404, "Applicant was not found.");
    }

    return { id: snapshot.id, ...snapshot.data() };
  }

  async updateApplicant(applicantId, updates) {
    const applicantRef = this.applicantsCollection().doc(applicantId.toUpperCase());
    const snapshot = await applicantRef.get();
    if (!snapshot.exists) {
      throw new AppError(404, "Applicant was not found.");
    }

    const allowedFields = [
      "phone",
      "state",
      "lga",
      "employmentStatus",
      "currentOccupation",
      "ownsLaptop",
      "internetAvailability",
      "facebookProfile",
      "xProfile",
      "linkedInProfile",
      "socialFollowers",
      "emergencyContactName",
      "emergencyContactPhone",
      "verificationStatus"
    ];

    const cleanUpdates = Object.fromEntries(
      Object.entries(updates).filter(([key]) => allowedFields.includes(key))
    );

    await applicantRef.update({
      ...cleanUpdates,
      updatedAt: FieldValue.serverTimestamp()
    });

    return this.getApplicant(applicantId);
  }

  async getPayment(reference) {
    const snapshot = await this.paymentsCollection().doc(reference).get();
    if (!snapshot.exists) {
      throw new AppError(404, "Payment reference was not found.");
    }

    return { id: snapshot.id, ...snapshot.data() };
  }

  async persistSuccessfulPayment(applicantId, reference, transaction, source) {
    const payment = await this.getPayment(reference);
    if (payment.applicantId !== applicantId) {
      throw new AppError(400, "Payment reference does not match Applicant ID.");
    }

    if (payment.paymentStatus === "Paid" && payment.receiptNumber) {
      return {
        applicantId,
        amountPaid: Number(payment.amountPaid ?? AMOUNT_KOBO),
        currency: CURRENCY,
        currentStatus: "Under review",
        paymentDate: formatTimestamp(payment.paidAt) || new Date().toISOString(),
        paymentReference: reference,
        receiptNumber: String(payment.receiptNumber)
      };
    }

    const paidAt = transaction.paid_at ?? new Date().toISOString();
    const receiptNumber = payment.receiptNumber ?? buildReceiptNumber(reference, paidAt);
    const applicantRef = this.applicantsCollection().doc(applicantId);
    const paymentRef = this.paymentsCollection().doc(reference);

    await this.db.runTransaction(async (firestoreTransaction) => {
      const applicantSnapshot = await firestoreTransaction.get(applicantRef);
      if (!applicantSnapshot.exists) {
        throw new AppError(404, "Applicant was not found.");
      }

      firestoreTransaction.update(applicantRef, {
        amountPaid: transaction.amount,
        authorizationCode: transaction.authorization?.authorization_code ?? null,
        paymentChannel: transaction.channel ?? null,
        paymentDate: Timestamp.fromDate(new Date(paidAt)),
        paymentReference: reference,
        paymentStatus: "Paid",
        receiptNumber,
        transactionId: String(transaction.id),
        verificationStatus: UNDER_REVIEW,
        updatedAt: FieldValue.serverTimestamp()
      });

      firestoreTransaction.update(paymentRef, {
        amountPaid: transaction.amount,
        authorizationCode: transaction.authorization?.authorization_code ?? null,
        cardBank: transaction.authorization?.bank ?? null,
        cardLast4: transaction.authorization?.last4 ?? null,
        cardType: transaction.authorization?.card_type ?? null,
        gatewayResponse: transaction.gateway_response ?? "Approved",
        paidAt: Timestamp.fromDate(new Date(paidAt)),
        paymentStatus: "Paid",
        receiptNumber,
        transactionId: String(transaction.id),
        updatedAt: FieldValue.serverTimestamp(),
        verifiedBy: source
      });

      firestoreTransaction.create(this.db.collection("StageHistory").doc(), {
        applicantId,
        fromStage: STAGE,
        toStage: STAGE,
        status: UNDER_REVIEW,
        createdAt: FieldValue.serverTimestamp()
      });

      firestoreTransaction.create(this.db.collection("AuditLogs").doc(), {
        action: "stage2_payment_verified",
        applicantId,
        paymentReference: reference,
        source,
        createdAt: FieldValue.serverTimestamp()
      });
    });

    return {
      applicantId,
      amountPaid: transaction.amount,
      currency: CURRENCY,
      currentStatus: "Under review",
      paymentDate: paidAt,
      paymentReference: reference,
      receiptNumber
    };
  }

  async logEmail(event) {
    await this.db.collection("EmailLogs").add({
      ...event,
      createdAt: FieldValue.serverTimestamp()
    });
  }

  async listApplicants(filters = {}) {
    const limit = Math.min(Number(filters.limit ?? 100), 1000);
    const snapshot = await this.applicantsCollection()
      .orderBy("submissionTime", "desc")
      .limit(limit)
      .get();

    const search = String(filters.search ?? "").toLowerCase();
    return snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((applicant) => {
        const matchesSearch =
          !search ||
          String(applicant.applicantId ?? "").toLowerCase().includes(search) ||
          String(applicant.firstName ?? "").toLowerCase().includes(search) ||
          String(applicant.lastName ?? "").toLowerCase().includes(search) ||
          String(applicant.email ?? "").toLowerCase().includes(search);
        const matchesState = !filters.state || applicant.state === filters.state;
        const matchesSkill =
          !filters.skill || applicant.preferredDigitalSkill === filters.skill;
        const matchesPayment =
          !filters.paymentStatus || applicant.paymentStatus === filters.paymentStatus;
        const matchesStage = !filters.stage || applicant.stage === filters.stage;
        return (
          matchesSearch &&
          matchesState &&
          matchesSkill &&
          matchesPayment &&
          matchesStage
        );
      });
  }

  async listPayments(filters = {}) {
    const limit = Math.min(Number(filters.limit ?? 100), 1000);
    const snapshot = await this.paymentsCollection()
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    return snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((payment) => {
        const matchesStatus =
          !filters.paymentStatus || payment.paymentStatus === filters.paymentStatus;
        const matchesApplicant =
          !filters.applicantId || payment.applicantId === String(filters.applicantId).toUpperCase();
        return matchesStatus && matchesApplicant;
      });
  }
}

function formatTimestamp(value) {
  if (value?.toDate) {
    return value.toDate().toISOString();
  }
  return "";
}

module.exports = {
  AMOUNT_KOBO,
  CURRENCY,
  STAGE,
  FirestoreService: new FirestoreService(),
  formatTimestamp
};
