const { AppError } = require("../middleware/errorHandler");
const {
  STAGE1_SPREADSHEET_HEADERS,
  buildStage1SpreadsheetRow
} = require("../utils/stage1");

class GoogleSheetsService {
  getWebhookUrl() {
    const webhookUrl = String(process.env.GOOGLE_APPS_SCRIPT_WEBHOOK ?? "").trim();
    if (!webhookUrl) {
      throw new AppError(500, "Google Sheets webhook is not configured.");
    }
    return webhookUrl;
  }

  getSheetName() {
    return String(process.env.GOOGLE_SHEETS_TAB_NAME ?? "Stage 1 Applications").trim();
  }

  async appendStage1Application(application) {
    const submittedAt = application.submittedAt ?? new Date().toISOString();
    const applicationPayload = {
      applicantId: application.applicantId,
      firstName: application.firstName,
      lastName: application.lastName,
      email: application.email,
      phone: application.phone,
      state: application.state,
      primarySkill: application.primarySkill,
      currentOccupation: application.currentOccupation,
      highestQualification: application.highestQualification,
      referralSource: application.referralSource,
      queueStatus: "",
      failureReason: "",
      retryCount: 0,
      status: application.status,
      submittedAt
    };

    const response = await fetch(this.getWebhookUrl(), {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        event: "stage1_application_submitted",
        sheetName: this.getSheetName(),
        spreadsheetHeaders: STAGE1_SPREADSHEET_HEADERS,
        applicantId: application.applicantId,
        submittedAt,
        row: buildStage1SpreadsheetRow(application),
        application: applicationPayload
      })
    });

    if (!response.ok) {
      const responseText = await response.text().catch(() => "");
      throw new Error(
        `Google Sheets webhook failed with ${response.status}. ${responseText}`.trim()
      );
    }

    return response;
  }
}

module.exports = new GoogleSheetsService();
