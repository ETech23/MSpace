const { AppError } = require("../middleware/errorHandler");
const { sanitizeValue } = require("../middleware/sanitize");
const { getIpAddress } = require("../utils/helpers");
const { isValidApplicantId, validateApplicantPayload } = require("../utils/validators");
const { FirestoreService } = require("./FirestoreService");

class ApplicantService {
  async createApplicant(payload, request) {
    const cleanPayload = sanitizeValue(payload);
    const validationError = validateApplicantPayload(cleanPayload);
    if (validationError) {
      throw new AppError(400, validationError);
    }

    return FirestoreService.createApplicant(cleanPayload, {
      ipAddress: getIpAddress(request),
      browser: String(request.headers["user-agent"] ?? "Unknown").slice(0, 500)
    });
  }

  async getApplicant(applicantId) {
    if (!isValidApplicantId(applicantId)) {
      throw new AppError(400, "Invalid Applicant ID.");
    }

    return FirestoreService.getApplicant(applicantId);
  }

  async updateApplicant(applicantId, updates) {
    if (!isValidApplicantId(applicantId)) {
      throw new AppError(400, "Invalid Applicant ID.");
    }

    return FirestoreService.updateApplicant(applicantId, sanitizeValue(updates));
  }
}

module.exports = new ApplicantService();
