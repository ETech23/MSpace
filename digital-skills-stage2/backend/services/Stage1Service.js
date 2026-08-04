const { AppError } = require("../middleware/errorHandler");
const { FieldValue } = require("firebase-admin/firestore");
const { getIpAddress } = require("../utils/helpers");
const {
  buildStage1ApplicantId,
  buildStage1FirestoreDocument,
  normalizeEmail,
  sanitizeStage1Payload,
  validateStage1ApplicationPayload
} = require("../utils/stage1");
const { FirestoreService } = require("./FirestoreService");
const GoogleSheetsService = require("./GoogleSheetsService");

class Stage1Service {
  async createApplication(payload, request) {
    const cleanPayload = sanitizeStage1Payload(payload);
    const validationError = validateStage1ApplicationPayload(cleanPayload);

    if (validationError) {
      throw new AppError(400, validationError);
    }

    const email = normalizeEmail(cleanPayload.email);
    const existing = await FirestoreService.findApplicantByEmail(email);

    if (existing) {
      throw new AppError(409, "This email has already been used to submit an application.");
    }

    const applicantId = buildStage1ApplicantId();
    const document = buildStage1FirestoreDocument(
      {
        ...cleanPayload,
        email
      },
      {
        ipAddress: getIpAddress(request),
        browser: String(request.headers["user-agent"] ?? "Unknown").slice(0, 500),
        submittedFrom: "web"
      },
      applicantId
    );

    await FirestoreService.applicantsCollection().doc(applicantId).set(document);

    let queueStatus = "Waiting";
    let failureReason = null;
    let retryCount = 0;

    try {
      await GoogleSheetsService.appendStage1Application({
        ...document,
        applicantId
      });
    } catch (error) {
      queueStatus = "Queued";
      failureReason = error instanceof Error ? error.message : "Spreadsheet sync failed.";
      retryCount = 1;
      const queuedApplication = {
        ...document,
        queueStatus,
        failureReason,
        retryCount
      };

      await FirestoreService.db.collection("SpreadsheetQueue").doc(applicantId).set({
        applicantId,
        stage: "Stage1",
        queueStatus,
        failureReason,
        retryCount,
        payload: queuedApplication,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });
    }

    await FirestoreService.applicantsCollection().doc(applicantId).update({
      queueStatus,
      failureReason,
      retryCount,
      sheetSyncStatus: queueStatus === "Queued" ? "Queued" : "Synced",
      sheetSyncedAt:
        queueStatus === "Queued" ? null : FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    });

    const application = await FirestoreService.getApplicant(applicantId);

    return {
      applicantId,
      stage: "Stage1",
      queueStatus,
      failureReason,
      retryCount,
      email: application.email ?? email,
      firstName: application.firstName ?? cleanPayload.firstName ?? "",
      lastName: application.lastName ?? cleanPayload.lastName ?? "",
      nextActionLink: application.nextActionLink,
      status: application.status,
      submittedAt: application.submissionTime?.toDate
        ? application.submissionTime.toDate().toISOString()
        : new Date().toISOString()
    };
  }

  async getApplication(applicantId) {
    if (!String(applicantId ?? "").trim()) {
      throw new AppError(400, "Applicant ID is required.");
    }

    const application = await FirestoreService.getApplicant(applicantId);
    return {
      ...application,
      submittedAt: application.submissionTime?.toDate
        ? application.submissionTime.toDate().toISOString()
        : ""
    };
  }
}

module.exports = new Stage1Service();
